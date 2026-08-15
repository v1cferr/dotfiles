# ═══════════════════════════════════════════════════════════════════════════
# duo-streak-daemon: the app's stack (a Playwright daemon plus API plus web plus Postgres)
# through Docker Compose, DECLARED in Nix (systemd brings it up at boot). The "brain" (the
# solver) is the host's NATIVE Ollama (see ./ollama.nix), and the compose talks to it on
# localhost:11434 through network_mode: host, exactly as the app was designed.
#
# Declarative end to end:
#   • the code is the `duo-streak-daemon` flake input (a commit pinned in flake.lock); the
#     compose builds straight from the store path, with no mutable clone and no manual build.
#   • the secrets are a sops template rendered into /run/secrets/rendered/duo.env (never in
#     plain text in git and never in /nix/store).
#
# AUTO-GATE: the module only ACTIVATES when the `duo_db_password` secret exists. Until it is
# provisioned (Bitwarden, then bitwarden-secrets.json, then sync-secrets), it stays INERT and
# the system keeps building normally.
#
# Turning it on (once):
#   1. Bitwarden: create the items (the VALUE always goes in the *password* field, because
#      sync-secrets uses `bw get password`):
#        "Duo DB Password"  (generate a strong password)   [required]
#        "Gemini API Key"   (a solver fallback)             [optional]
#        "ntfy Topic"       (the streak-at-risk alert; a shared topic)
#        "Duolingo"         (the account password)          [optional; the login fallback]
#        "Duolingo Email"   (the login email, in the password field) [the fallback's pair]
#   2. secrets/bitwarden-secrets.json: add the corresponding lines:
#        "duo_db_password": "Duo DB Password",
#        "gemini_api_key":  "Gemini API Key",      (only if created)
#        "ntfy_topic":      "ntfy Topic",           (already in the index)
#        "duolingo_password": "Duolingo",          (only if created)
#        "duolingo_username": "Duolingo Email"     (only if created)
#   3. `sync-secrets`  then  `sudo nixos-rebuild switch --flake .#nixos-kingston`
#
# The Duolingo session (a one-time interactive login, since the anti-bot does not like a
# headless one):
#   `duo-login` opens the browser, you sign in, and the session is saved in the duo-data
#   volume. After that the daemon keeps the streak alive on its own (once a day). To run it
#   right away: `duo-run-once`.
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  # It only turns on once the Postgres password has been provisioned (see AUTO-GATE above).
  enabled = config.sops.secrets ? duo_db_password;

  duoSrc = inputs.duo-streak-daemon; # the repo's store path (pinned in flake.lock)
  envPath = config.sops.templates."duo.env".path; # /run/secrets/rendered/duo.env

  # Waits for the Docker daemon to be REALLY ready (its API answering) before building. The
  # `after=docker.service` is not enough when dockerd comes up through socket activation and
  # BuildKit is still initializing (a race on the 1st boot).
  dockerReady = pkgs.writeShellScript "duo-wait-docker" ''
    for _ in $(seq 1 60); do ${pkgs.docker}/bin/docker info >/dev/null 2>&1 && exit 0; sleep 1; done
    echo "duo-stack: docker did not become ready in time" >&2; exit 1
  '';

  # Prepares a writable DOCKER_CONFIG (/run/duo) with the buildx and compose plugins linked in.
  # Without this, the service's root does not DISCOVER buildx and `compose build` falls back to
  # the LEGACY builder, which does not support `RUN --mount` (the error that blocked
  # everything).
  dockerCfgSetup = pkgs.writeShellScript "duo-docker-cfg" ''
    mkdir -p /run/duo/cli-plugins
    ln -sf ${pkgs.docker-buildx}/libexec/docker/cli-plugins/docker-buildx /run/duo/cli-plugins/docker-buildx
    ln -sf ${pkgs.docker-compose}/libexec/docker/cli-plugins/docker-compose /run/duo/cli-plugins/docker-compose
  '';

  # `docker compose` (the PLUGIN, not the standalone binary, since only the plugin routes to
  # buildx/BuildKit) plus a FIXED project name 'duo' (otherwise the name would become the store
  # path's hash and the volumes and containers would change on every bump).
  dc = "${pkgs.docker}/bin/docker compose -p duo --env-file ${envPath} -f ${composeFile}";

  # The DEPLOY manifest (the repo has the DEV one): contexts are store paths, and the secrets
  # come through an env_file pointing at the file rendered by sops (not the values).
  composeFile = pkgs.writeText "duo-compose.yml" ''
    services:
      duo-daemon:
        build: { context: ${duoSrc}, dockerfile: src/daemon/Dockerfile }
        image: duo-daemon:latest
        container_name: duo-daemon
        restart: unless-stopped
        env_file: [ ${envPath} ]
        environment: { DATA_DIR: /data, HEADLESS: "true" }
        network_mode: host
        volumes: [ "duo-data:/data" ]
        shm_size: "1gb"

      duo-db:
        image: supabase/postgres:17.6.1.142
        container_name: duo-db
        restart: unless-stopped
        env_file: [ ${envPath} ]
        environment: { POSTGRES_PASSWORD: "''${DUO_DB_PASSWORD}" }
        ports: [ "127.0.0.1:5432:5432" ]
        volumes: [ "duo-db-data:/var/lib/postgresql/data" ]

      duo-api:
        build: { context: ${duoSrc}, dockerfile: src/api/Dockerfile }
        image: duo-api:latest
        container_name: duo-api
        restart: unless-stopped
        env_file: [ ${envPath} ]
        environment:
          DATA_DIR: /data
          DATABASE_URL: "postgresql://postgres:''${DUO_DB_PASSWORD}@127.0.0.1:5432/postgres"
        network_mode: host
        volumes: [ "duo-data:/data" ]

      duo-web:
        build: { context: ${duoSrc}/src/web }
        image: duo-web:latest
        container_name: duo-web
        restart: unless-stopped
        network_mode: host
        depends_on: [ duo-api ]

    volumes:
      duo-data: {}
      duo-db-data: {}
  '';

  # The one-time interactive login: it starts an ephemeral container from the SAME image with
  # the browser visible (through Xwayland/DISPLAY), and the session persists in the
  # duo_duo-data volume.
  duo-login = pkgs.writeShellApplication {
    name = "duo-login";
    runtimeInputs = [
      pkgs.docker
      pkgs.xhost
    ];
    text = ''
      xhost +local: >/dev/null 2>&1 || true
      trap 'xhost -local: >/dev/null 2>&1 || true' EXIT
      docker run --rm -it --network host \
        --env-file ${envPath} \
        -e DISPLAY="''${DISPLAY:-:0}" -e DATA_DIR=/data -e HEADLESS=false \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        -v duo_duo-data:/data \
        duo-daemon:latest login
    '';
  };

  # Runs the routine NOW (ignoring the "it already ran today"), useful for testing or forcing.
  duo-run-once = pkgs.writeShellApplication {
    name = "duo-run-once";
    runtimeInputs = [ pkgs.docker ];
    text = ''docker exec -it duo-daemon duo-streak-daemon run-once --force "$@"'';
  };
in
lib.mkIf (enabled && config.my.services.duo) {
  virtualisation.docker = {
    enable = true; # the engine declared in Nix
    # The app's Dockerfiles use `RUN --mount=type=cache`, which requires BuildKit (the legacy
    # builder ignores it). This turns BuildKit on as the daemon's default.
    daemon.settings.features.buildkit = true;
  };
  users.users.v1cferr.extraGroups = [ "docker" ]; # to run docker and duo-login without sudo

  environment.systemPackages = [
    duo-login
    duo-run-once
    pkgs.docker-compose
  ];

  # The .env rendered by sops: config as text plus secrets through placeholders. The optional
  # lines only enter if the corresponding secret was provisioned.
  # owner = v1cferr: the service runs as root (and reads everything), but `duo-login` runs as
  # the user and needs to READ this file (--env-file).
  sops.templates."duo.env".owner = "v1cferr";
  sops.templates."duo.env".content = ''
    TZ=America/Sao_Paulo
    TIMEZONE=America/Sao_Paulo
    RUN_AT=08:00
    HEADLESS=true
    CHECK_INTERVAL_SECONDS=60
    RUN_ON_START=false
    DATA_DIR=/data
    ACTIVITY=practice
    SOLVER=ollama
    OLLAMA_HOST=http://localhost:11434
    OLLAMA_MODEL=qwen3:4b
    LOG_LEVEL=INFO
    NTFY_URL=https://ntfy.sh
    ALERT_AFTER=20:00
    GPU_VRAM_MB=8192
    DUO_DB_PASSWORD=${config.sops.placeholder.duo_db_password}
  ''
  + lib.optionalString (
    config.sops.secrets ? gemini_api_key
  ) "GEMINI_API_KEY=${config.sops.placeholder.gemini_api_key}\n"
  + lib.optionalString (
    config.sops.secrets ? ntfy_topic
  ) "NTFY_TOPIC=${config.sops.placeholder.ntfy_topic}\n"
  + lib.optionalString (
    config.sops.secrets ? duolingo_username
  ) "DUOLINGO_USERNAME=${config.sops.placeholder.duolingo_username}\n"
  + lib.optionalString (
    config.sops.secrets ? duolingo_password
  ) "DUOLINGO_PASSWORD=${config.sops.placeholder.duolingo_password}\n";

  # Brings the stack up and down through compose. It only builds what is missing (the layers
  # are cached). It depends on Docker and on the native Ollama (the solver the daemon consumes).
  systemd.services.duo-stack = {
    description = "duo-streak-daemon stack (compose: daemon + api + web + db)";
    after = [
      "docker.service"
      "network-online.target"
      "ollama.service"
    ];
    requires = [ "docker.service" ];
    wants = [
      "network-online.target"
      "ollama.service"
    ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.docker ];
    # Changing the compose OR the STRUCTURE of the .env makes the switch restart the service,
    # and `up -d` recreates the affected containers (applying the new env). (A change in the
    # VALUE of a secret alone does not change the hash here; in that case:
    # systemctl restart duo-stack.)
    restartTriggers = [
      composeFile
      config.sops.templates."duo.env".content
    ];
    # DOCKER_CONFIG points at the dir with the plugins (see dockerCfgSetup), so Compose finds
    # buildx and uses BuildKit. DOCKER_BUILDKIT=1 reinforces it.
    environment = {
      DOCKER_CONFIG = "/run/duo";
      DOCKER_BUILDKIT = "1";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "duo"; # creates /run/duo (writable for the DOCKER_CONFIG above)
      TimeoutStartSec = "1800"; # the 1st start builds 3 images (Playwright/Next.js), which takes a while
      # wait for the daemon, then prepare the plugins, then build (with cache, quickly)
      ExecStartPre = [
        dockerReady
        dockerCfgSetup
        "${dc} build"
      ];

      ExecStart = "${dc} up -d --remove-orphans";
      ExecStop = "${dc} down";
    };
  };
}
