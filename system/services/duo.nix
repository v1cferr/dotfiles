# ═══════════════════════════════════════════════════════════════════════════
# duo-streak-daemon — stack do app (daemon Playwright + API + web + Postgres) via
# Docker Compose, DECLARADO no Nix (systemd sobe no boot). O "cérebro" (solver)
# é o Ollama NATIVO do host (ver ./ollama.nix) — o compose fala com ele em
# localhost:11434 via network_mode: host, exatamente como o app foi desenhado.
#
# Declarativo de ponta a ponta:
#   • código = flake input `duo-streak-daemon` (commit fixo no flake.lock); o
#     compose builda direto do store-path — nada de clone mutável nem build manual.
#   • segredos = template sops → /run/secrets/rendered/duo.env (nunca em texto
#     plano no git nem na /nix/store).
#
# AUTO-GATE: o módulo só ATIVA quando existir o segredo `duo_db_password`. Enquanto
# você não provisionar (Bitwarden → bitwarden-secrets.json → sync-secrets), ele fica
# INERTE e o sistema continua buildando normal.
#
# Ligar (uma vez):
#   1. Bitwarden: crie os itens (o VALOR vai sempre no campo *senha*, pois o
#      sync-secrets usa `bw get password`):
#        "Duo DB Password"  (gere uma senha forte)    [obrigatório]
#        "Gemini API Key"   (reserva do solver)        [opcional]
#        "Duo ntfy Topic"   (alerta ofensiva em risco) [opcional]
#        "Duolingo"         (senha da conta)            [opcional; fallback do login]
#        "Duolingo Email"   (o e-mail de login, no campo senha) [par do fallback]
#   2. secrets/bitwarden-secrets.json: some as linhas correspondentes:
#        "duo_db_password": "Duo DB Password",
#        "gemini_api_key":  "Gemini API Key",      (só se criou)
#        "ntfy_topic":      "Duo ntfy Topic",      (só se criou)
#        "duolingo_password": "Duolingo",          (só se criou)
#        "duolingo_username": "Duolingo Email"     (só se criou)
#   3. `sync-secrets`  →  `sudo nixos-rebuild switch --flake .#nixos-seagate`
#
# Sessão do Duolingo (login 1x, interativo — anti-bot não gosta de login headless):
#   `duo-login`  → abre o navegador, você entra, a sessão salva no volume duo-data.
#   Depois o daemon mantém a ofensiva sozinho (1x/dia). Rodar já: `duo-run-once`.
# ═══════════════════════════════════════════════════════════════════════════
{ config, pkgs, lib, inputs, ... }:

let
  # Só liga quando a senha do Postgres já foi provisionada (ver AUTO-GATE acima).
  enabled = config.sops.secrets ? duo_db_password;

  duoSrc = inputs.duo-streak-daemon; # store-path do repo (fixo no flake.lock)
  envPath = config.sops.templates."duo.env".path; # /run/secrets/rendered/duo.env

  # Espera o daemon do Docker ficar REALMENTE pronto (API responde) antes de
  # buildar — o `after=docker.service` não basta quando o dockerd sobe por
  # socket-activation e o BuildKit ainda está inicializando (corrida no 1º boot).
  dockerReady = pkgs.writeShellScript "duo-wait-docker" ''
    for _ in $(seq 1 60); do ${pkgs.docker}/bin/docker info >/dev/null 2>&1 && exit 0; sleep 1; done
    echo "duo-stack: docker não ficou pronto a tempo" >&2; exit 1
  '';

  # Prepara um DOCKER_CONFIG writable (/run/duo) com os plugins buildx+compose
  # linkados. Sem isso, o root do serviço não DESCOBRE o buildx e o `compose build`
  # cai no builder LEGADO — que não suporta `RUN --mount` (o erro que travava tudo).
  dockerCfgSetup = pkgs.writeShellScript "duo-docker-cfg" ''
    mkdir -p /run/duo/cli-plugins
    ln -sf ${pkgs.docker-buildx}/libexec/docker/cli-plugins/docker-buildx /run/duo/cli-plugins/docker-buildx
    ln -sf ${pkgs.docker-compose}/libexec/docker/cli-plugins/docker-compose /run/duo/cli-plugins/docker-compose
  '';

  # `docker compose` (PLUGIN, não o binário standalone — só o plugin roteia pro
  # buildx/BuildKit) + projeto FIXO 'duo' (senão o nome viraria o hash do
  # store-path e os volumes/containers mudariam a cada bump).
  dc = "${pkgs.docker}/bin/docker compose -p duo --env-file ${envPath} -f ${composeFile}";

  # Manifesto de DEPLOY (o repo tem o de DEV): contexts = store-path, segredos via
  # env_file apontando pro arquivo renderizado pelo sops (não os valores).
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

  # Login interativo 1x: sobe um container efêmero da MESMA imagem com o navegador
  # visível (via Xwayland/DISPLAY) e a sessão persiste no volume duo_duo-data.
  duo-login = pkgs.writeShellApplication {
    name = "duo-login";
    runtimeInputs = [ pkgs.docker pkgs.xhost ];
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

  # Roda a rotina AGORA (ignora o "já rodou hoje") — útil pra testar/forçar.
  duo-run-once = pkgs.writeShellApplication {
    name = "duo-run-once";
    runtimeInputs = [ pkgs.docker ];
    text = ''docker exec -it duo-daemon duo-streak-daemon run-once --force "$@"'';
  };
in
lib.mkIf enabled {
  virtualisation.docker = {
    enable = true; # engine declarada no Nix
    # Os Dockerfiles do app usam `RUN --mount=type=cache` → exige BuildKit (o
    # builder legado ignora). Liga o BuildKit como padrão do daemon.
    daemon.settings.features.buildkit = true;
  };
  users.users.v1cferr.extraGroups = [ "docker" ]; # rodar docker/duo-login sem sudo

  environment.systemPackages = [ duo-login duo-run-once pkgs.docker-compose ];

  # .env renderizado pelo sops: config em texto + segredos por placeholder. As
  # linhas opcionais só entram se o segredo correspondente foi provisionado.
  # owner = v1cferr: o serviço roda como root (lê tudo), mas o `duo-login` roda
  # como usuário e precisa LER este arquivo (--env-file).
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
  + lib.optionalString (config.sops.secrets ? gemini_api_key)
      "GEMINI_API_KEY=${config.sops.placeholder.gemini_api_key}\n"
  + lib.optionalString (config.sops.secrets ? ntfy_topic)
      "NTFY_TOPIC=${config.sops.placeholder.ntfy_topic}\n"
  + lib.optionalString (config.sops.secrets ? duolingo_username)
      "DUOLINGO_USERNAME=${config.sops.placeholder.duolingo_username}\n"
  + lib.optionalString (config.sops.secrets ? duolingo_password)
      "DUOLINGO_PASSWORD=${config.sops.placeholder.duolingo_password}\n";

  # Sobe/derruba o stack via compose. Só builda o que faltar (camadas em cache).
  # Depende do Docker e do Ollama nativo (o solver que o daemon consome).
  systemd.services.duo-stack = {
    description = "duo-streak-daemon stack (compose: daemon + api + web + db)";
    after = [ "docker.service" "network-online.target" "ollama.service" ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" "ollama.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.docker ];
    # Muda o compose OU a ESTRUTURA do .env → o switch reinicia o serviço → `up -d`
    # recria os containers afetados (aplica env novo). (Mudança só de VALOR de
    # segredo não altera o hash aqui; nesse caso: systemctl restart duo-stack.)
    restartTriggers = [ composeFile config.sops.templates."duo.env".content ];
    # DOCKER_CONFIG aponta pro dir com os plugins (ver dockerCfgSetup) → o Compose
    # acha o buildx e usa BuildKit. DOCKER_BUILDKIT=1 reforça.
    environment = {
      DOCKER_CONFIG = "/run/duo";
      DOCKER_BUILDKIT = "1";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "duo"; # cria /run/duo (writable p/ o DOCKER_CONFIG acima)
      TimeoutStartSec = "1800"; # 1º start builda 3 imagens (Playwright/Next.js) — demora
      # espera o daemon → prepara os plugins → builda (com cache, rápido)
      ExecStartPre = [ dockerReady dockerCfgSetup "${dc} build" ];

      ExecStart = "${dc} up -d --remove-orphans";
      ExecStop = "${dc} down";
    };
  };
}
