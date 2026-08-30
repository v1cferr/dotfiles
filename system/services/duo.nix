# DUO-STREAK-DAEMON: the compose stack DECLARED in Nix (a flake input plus a sops-rendered .env),
# up at boot. Turning it on, `duo-login` and the 3 Docker traps: docs/notes/services/duo.md
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  # Every package this module reaches for, named ONCE and up front: an entry that stops being used
  # fails the build under deadnix, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    docker
    docker-buildx
    docker-compose
    writeShellApplication
    writeShellScript
    writeText
    xhost
    ;

  # The auto-gate: it stays inert until the Postgres password is provisioned.
  enabled = config.sops.secrets ? duo_db_password;

  duoSrc = inputs.duo-streak-daemon; # the repo's store path (pinned in flake.lock)
  envPath = config.sops.templates."duo.env".path; # /run/secrets/rendered/duo.env

  # dockerd comes up through socket activation, so `after=docker.service` loses the race.
  dockerReady = writeShellScript "duo-wait-docker" ''
    for _ in $(seq 1 60); do ${docker}/bin/docker info >/dev/null 2>&1 && exit 0; sleep 1; done
    echo "duo-stack: docker did not become ready in time" >&2; exit 1
  '';

  # A writable DOCKER_CONFIG with the plugins: without it buildx is not found and the LEGACY
  # builder takes over, which does not support `RUN --mount`. See the notes.
  dockerCfgSetup = writeShellScript "duo-docker-cfg" ''
    mkdir -p /run/duo/cli-plugins
    ln -sf ${docker-buildx}/libexec/docker/cli-plugins/docker-buildx /run/duo/cli-plugins/docker-buildx
    ln -sf ${docker-compose}/libexec/docker/cli-plugins/docker-compose /run/duo/cli-plugins/docker-compose
  '';

  # The PLUGIN (only it routes to buildx) plus a FIXED project name, so the volumes survive a bump.
  dc = "${docker}/bin/docker compose -p duo --env-file ${envPath} -f ${composeFile}";

  # The DEPLOY manifest (the repo ships the DEV one): store paths plus a sops-rendered env_file.
  composeFile = writeText "duo-compose.yml" ''
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

  # The one-time interactive login: the browser visible through Xwayland, the session in the volume.
  duo-login = writeShellApplication {
    name = "duo-login";
    runtimeInputs = [
      docker
      xhost
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

  # Runs the routine NOW, ignoring the "it already ran today".
  duo-run-once = writeShellApplication {
    name = "duo-run-once";
    runtimeInputs = [ docker ];
    text = ''docker exec -it duo-daemon duo-streak-daemon run-once --force "$@"'';
  };
in
lib.mkIf (enabled && config.my.services.duo) {
  virtualisation.docker = {
    enable = true; # the engine declared in Nix
    # The Dockerfiles use `RUN --mount=type=cache`, which the legacy builder ignores.
    daemon.settings.features.buildkit = true;
  };
  users.users.v1cferr.extraGroups = [ "docker" ]; # to run docker and duo-login without sudo

  environment.systemPackages = [
    duo-login
    duo-run-once
    docker-compose
  ];

  # The .env rendered by sops: config as text plus secrets through placeholders, the optional ones
  # only if provisioned. owner = v1cferr because `duo-login` runs as the user and reads it.
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

  # It only builds what is missing (the layers are cached), and it needs the native Ollama.
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
    path = [ docker ];
    # A change in a secret's VALUE alone does not move this hash: `systemctl restart duo-stack`.
    restartTriggers = [
      composeFile
      config.sops.templates."duo.env".content
    ];
    # DOCKER_CONFIG points at the dir with the plugins, so Compose finds buildx.
    environment = {
      DOCKER_CONFIG = "/run/duo";
      DOCKER_BUILDKIT = "1";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "duo"; # creates /run/duo (writable for the DOCKER_CONFIG above)
      TimeoutStartSec = "1800"; # the 1st start builds 3 images (Playwright/Next.js), which takes a while
      # wait for the daemon, prepare the plugins, then build (cached, quick)
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
