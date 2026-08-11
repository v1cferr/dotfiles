# ═══════════════════════════════════════════════════════════════════════════
# GradRadar — stack do app (Next.js + FastAPI + Postgres) subindo no BOOT, e a
# cadeia de acompanhamento de editais rodando por timer: coleta → reavalia
# horário → notifica.
#
# O PROBLEMA QUE ISTO RESOLVE: o Caddy já subia sozinho e o Docker também, mas
# os containers do grad-radar não. Depois de cada reboot o
# https://pos.v1cferr.dev respondia 502 — o proxy no ar, sem upstream — até
# alguém rodar `just dev` à mão. Um link que só funciona quando o dono está na
# frente do PC não serve para mandar pro JP e pro César.
#
# POR QUE systemd E NÃO `restart: unless-stopped` NO COMPOSE: o compose de dev
# declara `restart: "no"` de propósito, e o comentário lá explica — containers
# que ressuscitam sozinhos depois de um restart do daemon viram órfãos rodando
# sem ninguém pedir. Um oneshot com RemainAfterExit dá o boot sem trazer de
# volta esse comportamento: quem manda subir é o boot, não o dockerd.
#
# POR QUE O CAMINHO DA ÁRVORE DE TRABALHO E NÃO UM STORE-PATH: ao contrário do
# ./duo.nix, que consome um flake input com commit fixo, este aponta para o
# repositório onde o desenvolvimento acontece. É uma escolha consciente e tem
# custo: o que está no ar é o commit que está em disco, não um pinado no
# flake.lock. Em troca, `just dev` e o serviço são O MESMO stack — mesmo nome de
# projeto, mesmas portas, mesmos volumes —, então não brigam pela 3006/8006 e
# não existem duas cópias divergindo. Enquanto o projeto for editado toda
# semana, essa é a troca certa; quando estabilizar, vira flake input.
#
# É UM SERVIDOR DE DESENVOLVIMENTO EXPOSTO. O frontend roda `next dev`, não
# `next build && next start`: recompila sob demanda, gasta mais memória e é bem
# mais lento no primeiro acesso. Para três pessoas conferindo prazo, serve. Se
# virar algo mais, o passo é um compose de produção — não mexer neste.
#
# Ligar:  my.services.grad-radar = true;  em hosts/<host>/services.nix
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Árvore de trabalho, não store-path (ver cabeçalho). String de runtime: o Nix
  # nunca lê este caminho em tempo de avaliação, então a impureza fica contida
  # na unidade do systemd e não contamina o flake.
  repo = "/home/v1cferr/Projects/GitHub/v1cferr/grad-radar";
  composeFile = "${repo}/docker-compose.dev.yml";

  # Mesma corrida do ./duo.nix: `after = docker.service` não basta quando o
  # dockerd sobe por socket-activation e a API ainda não responde.
  dockerReady = pkgs.writeShellScript "grad-radar-wait-docker" ''
    for _ in $(seq 1 60); do ${pkgs.docker}/bin/docker info >/dev/null 2>&1 && exit 0; sleep 1; done
    echo "grad-radar: docker não ficou pronto a tempo" >&2; exit 1
  '';

  # DOCKER_CONFIG writable com os plugins linkados — sem isso o root não
  # DESCOBRE o buildx e o build cai no builder legado. Lição do ./duo.nix.
  dockerCfgSetup = pkgs.writeShellScript "grad-radar-docker-cfg" ''
    mkdir -p /run/grad-radar/cli-plugins
    ln -sf ${pkgs.docker-buildx}/libexec/docker/cli-plugins/docker-buildx /run/grad-radar/cli-plugins/docker-buildx
    ln -sf ${pkgs.docker-compose}/libexec/docker/cli-plugins/docker-compose /run/grad-radar/cli-plugins/docker-compose
  '';

  # `-p grad-radar` casa com o `name:` do compose — sem isso o serviço criaria um
  # projeto separado, com volumes próprios, e o `just dev` passaria a olhar para
  # um banco diferente do que está publicado.
  dc = "${pkgs.docker}/bin/docker compose -p grad-radar -f ${composeFile}";
in
lib.mkIf config.my.services.grad-radar {
  virtualisation.docker.enable = true;
  users.users.v1cferr.extraGroups = [ "docker" ];
  environment.systemPackages = [ pkgs.docker-compose ];

  systemd.services.grad-radar = {
    description = "GradRadar stack (compose: frontend + backend + db)";
    after = [
      "docker.service"
      "network-online.target"
    ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.docker ];

    environment = {
      DOCKER_CONFIG = "/run/grad-radar";
      DOCKER_BUILDKIT = "1";
    };

    unitConfig = {
      # O repositório é da árvore de trabalho: pode não existir (host novo, clone
      # ainda não feito). ConditionPathExists faz a unidade ser PULADA em vez de
      # falhar — um serviço vermelho por um clone ausente treina a pessoa a
      # ignorar serviço vermelho.
      ConditionPathExists = composeFile;
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "grad-radar";
      # O primeiro start builda duas imagens e o `pnpm install` do frontend roda
      # dentro do container — leva minutos numa máquina fria.
      TimeoutStartSec = "1800";
      ExecStartPre = [
        dockerReady
        dockerCfgSetup
        "${dc} build"
      ];
      ExecStart = "${dc} up -d --remove-orphans --wait";
      ExecStop = "${dc} down";
    };
  };

  # ── Monitor de editais ────────────────────────────────────────────────────
  # Até aqui o coletor só rodava quando alguém digitava `just monitor`. Um
  # monitor que depende de alguém lembrar de rodá-lo não é um monitor — é
  # exatamente a falha que o projeto existe para evitar, só que com mais passos.
  systemd.services.grad-radar-monitor = {
    description = "GradRadar — checa as fontes oficiais uma vez";
    after = [ "grad-radar.service" ];
    requires = [ "grad-radar.service" ];
    path = [ pkgs.docker ];
    unitConfig.ConditionPathExists = composeFile;
    serviceConfig = {
      Type = "oneshot";
      # --quiet: só mudança e falha viram log. Um journal com 19 linhas de
      # "igual" por hora é um journal que ninguém lê.
      #
      # `verify` roda DEPOIS e sem --apply: ele relê as grades que o monitor
      # acabou de baixar e compara o veredito de horário com o que está no banco.
      # Relatar e não gravar é deliberado — divergência pode ser grade nova (o que
      # se quer saber) ou o extrator falhando num formato inédito, e gravar calado
      # apagaria a diferença. Quem decide é uma pessoa, com `just verify-apply`.
      # A cadeia inteira, na ordem: coleta → reavalia horário → avisa.
      #
      # `notify` por último e por um motivo: ele lê o que os dois anteriores
      # acabaram de gravar. Rodar antes avisaria sobre o estado da execução
      # passada, e um alerta atrasado de um dia é pior que nenhum num projeto cujo
      # inimigo é justamente descobrir tarde.
      #
      # Sem canal configurado, `notify` só GRAVA os eventos — não falha. Isso é de
      # propósito: a cadeia não deve quebrar por falta de credencial, e os eventos
      # ficam na tabela esperando o canal existir.
      ExecStart = [
        "${dc} exec -T backend python -m app.monitor --quiet"
        "${dc} exec -T backend python -m app.verify"
        "${dc} exec -T backend python -m app.notify"
      ];
    };
  };

  systemd.timers.grad-radar-monitor = {
    description = "GradRadar — checagem periódica das fontes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Duas vezes por dia. Editais não mudam de hora em hora, e a única janela
      # que importa dura semanas; checar mais seria carga em cima da UFSCar sem
      # ganho nenhum.
      OnCalendar = "08:00,20:00";
      # A máquina é um desktop e passa noites desligada. Sem isto, uma checagem
      # perdida some para sempre — que é precisamente o modo de falha do projeto.
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
  };
}
