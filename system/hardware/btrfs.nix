# ═══════════════════════════════════════════════════════════════════════════
# BTRFS — integridade e manutenção do filesystem (SSOT da POLÍTICA de btrfs).
#
# Divisão de trabalho, pra não procurar no lugar errado:
#   • LAYOUT (subvolumes, opções de mount)  → hosts/<host>/disko.nix
#   • POLÍTICA (scrub, alarme, reclaim…)    → AQUI
#   • SNAPSHOTS (retenção, agenda)          → system/services/btrbk.nix
#
# Machine-agnostic de propósito (mora em system/, não em hosts/): tudo aqui está
# atrás do guarda `raiz é btrfs?`, então um host futuro em ext4 simplesmente não
# recebe nada disto — em vez de quebrar com uma unit de scrub apontando pra um
# filesystem que não tem checksum.
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  lib,
  pkgs,
  utils,
  ...
}:

let
  rootIsBtrfs = config.fileSystems ? "/" && config.fileSystems."/".fsType == "btrfs";

  # O módulo do autoScrub nomeia a unit com o caminho ESCAPADO ("/" vira "-", daí
  # o "btrfs-scrub--"). Derivar em vez de escrever o nome à mão: se o alvo do
  # scrub mudar, o onFailure acompanha em vez de apontar pra unit inexistente.
  scrubUnit = "btrfs-scrub-${utils.escapeSystemdPath "/"}";

  # Usuários reais da máquina (SSOT: sai de users.users, não de um literal). É a
  # lista de sessões que podem receber a bolha do alarme abaixo.
  normalUsers = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);

  # ── ALARME ────────────────────────────────────────────────────────────────
  # Erro de checksum é a informação mais cara que este filesystem produz, e a que
  # menos perdoa atraso — então ela sai por DOIS canais, nesta ordem:
  #   1. journal (@log, subvolume próprio) — sobrevive a não ter ninguém logado;
  #   2. notificação crítica (fica na tela, não some sozinha) em TODA sessão viva.
  # O canal 2 é o que você vê; o 1 é o que garante que a mensagem existiu.
  #
  # runuser + DBUS_SESSION_BUS_ADDRESS porque quem entrega notificação aqui é o
  # Quickshell, que roda na sessão do usuário — uma unit de sistema não fala com
  # ele sem entrar no bus certo.
  btrfsAlert = pkgs.writeShellApplication {
    name = "btrfs-alert";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
      util-linux
    ];
    text = ''
      title="$1"
      body="$2"

      printf 'BTRFS ALERTA: %s\n%s\n' "$title" "$body" >&2

      # Array (e não `for u in <lista>`) porque o Nix pode gerar UM nome só, e aí
      # o shellcheck do writeShellApplication reclama de loop que roda uma vez.
      users=( ${lib.escapeShellArgs normalUsers} )
      for u in "''${users[@]}"; do
        uid="$(id -u "$u" 2>/dev/null)" || continue
        bus="/run/user/$uid/bus"
        [ -S "$bus" ] || continue   # sem sessão viva → só o journal, e tudo bem
        # Caminho ABSOLUTO do notify-send: o runuser pode remontar o PATH ao
        # trocar de usuário, e aí o binário do libnotify sumiria do alcance.
        runuser -u "$u" -- env "DBUS_SESSION_BUS_ADDRESS=unix:path=$bus" \
          ${pkgs.libnotify}/bin/notify-send -a "btrfs" -u critical \
          -i drive-harddisk "$title" "$body" || true
      done
    '';
  };
in
lib.mkIf rootIsBtrfs {
  # ═══ SCRUB: relê TODO bloco e confere o checksum ═══════════════════════════
  # Sem scrub o checksum só acusa erro quando você por acaso lê o setor podre —
  # ou seja, no dia em que o arquivo importa. Em ext4 isso nem existia.
  # UM alvo basta: scrub é por FILESYSTEM, não por subvolume — "/" já cobre
  # @home, @nix, @persist e @log, que são o mesmo /dev/nvme0n1p2.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # `btrfs scrub start -B` sai com código != 0 quando encontra erro (corrigível
  # ou não) — é esse exit que vira alarme. ANTES disto o scrub rodava e falhava
  # em silêncio: scrub que ninguém lê é o mesmo que scrub desligado.
  systemd.services.${scrubUnit}.onFailure = [ "btrfs-alert-scrub.service" ];

  systemd.services.btrfs-alert-scrub = {
    description = "Alarme: o scrub do btrfs encontrou erro";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''
        ${btrfsAlert}/bin/btrfs-alert \
          "btrfs: erro no scrub de /" \
          "O scrub mensal falhou. Rode 'sudo btrfs scrub status /' e 'sudo btrfs device stats /'. Se houver erro incorrigível, o dado afetado está perdido nesta cópia — restaure do restic."
      '';
    };
  };

  # ═══ CONTADORES DE ERRO: o vigia entre um scrub e outro ════════════════════
  # O scrub é mensal; um NVMe que começa a falhar no dia 2 ficaria 28 dias sem
  # aviso. Estes contadores são persistentes e sobem a CADA I/O ruim (read/write/
  # flush/corruption/generation), então checá-los é barato e pega o problema cedo.
  # `-c` = sai != 0 se algum contador for diferente de zero.
  #
  # Contador não zera sozinho: depois de investigar, reconheça com
  # `sudo btrfs device stats -z /` — senão o alarme (corretamente) repete todo dia.
  systemd.services.btrfs-device-stats = {
    description = "Checa os contadores de erro de I/O do btrfs";
    onFailure = [ "btrfs-alert-devstats.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.btrfs-progs}/bin/btrfs device stats -c /";
      LogLevelMax = "warning"; # não loga "Starting/Finished" todo dia (lição do bb8690c)
    };
  };

  systemd.timers.btrfs-device-stats = {
    description = "Checagem diária dos contadores de erro do btrfs";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true; # máquina desligada na hora marcada → roda no próximo boot
      RandomizedDelaySec = "10min";
    };
  };

  systemd.services.btrfs-alert-devstats = {
    description = "Alarme: contador de erro de I/O do btrfs != 0";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''
        ${btrfsAlert}/bin/btrfs-alert \
          "btrfs: contador de erro de I/O != 0" \
          "O disco registrou erro de leitura/escrita/corrupção. Veja 'sudo btrfs device stats /' e o SMART ('sudo smartctl -a /dev/nvme0'). Reconheça com 'sudo btrfs device stats -z /' DEPOIS de investigar."
      '';
    };
  };

  # ═══ RECLAIM AUTOMÁTICO DE BLOCK GROUP (substitui o balance periódico) ═════
  # O footgun clássico do btrfs: ele aloca block groups pra dado/metadado e não
  # os devolve quando esvaziam — o disco fica "cheio" (ENOSPC) com espaço livre
  # aparecendo no df. A receita antiga era um cron de `btrfs balance -dusage=N`
  # (btrfsmaintenance). Desde o kernel 6.11 isso é FEATURE DO KERNEL, e o kernel
  # sabe algo que o cron não sabe: quando NÃO vale a pena relocar.
  #   • dynamic_reclaim=1 → o limiar deixa de ser fixo e passa a ser calculado
  #     (alvo de 10 block groups não alocados, agressividade proporcional ao
  #     aperto). Reloca ~nada com o disco folgado, que é o caso hoje (49%).
  #   • periodic_reclaim=1 → o cleaner thread varre de tempos em tempos e marca
  #     os candidatos.
  # Escrever em bg_reclaim_threshold seria EINVAL com dynamic_reclaim ligado (é
  # mutuamente exclusivo no kernel) — por isso não mexemos nele.
  #
  # Só data e metadata: block group de `system` é minúsculo e relocá-lo é risco
  # sem retorno. Escape hatch manual continua existindo: `btrfs balance start -dusage=10 /`.
  systemd.services.btrfs-reclaim-tuning = {
    description = "Liga o reclaim automático de block group (dynamic + periodic)";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # Loop sobre todos os btrfs montados: o glob */allocation não casa com
    # /sys/fs/btrfs/features, e um UUID hardcoded aqui seria literal duplicado
    # do disko (regra 11). `|| true` porque kernel sem a feature não pode
    # derrubar o boot.
    script = ''
      for alloc in /sys/fs/btrfs/*/allocation; do
        for kind in data metadata; do
          echo 1 > "$alloc/$kind/dynamic_reclaim"  || true
          echo 1 > "$alloc/$kind/periodic_reclaim" || true
        done
      done
    '';
  };

  # ═══ TRIM: um só, não dois ════════════════════════════════════════════════
  # Desde o kernel 6.2 o btrfs liga `discard=async` sozinho em SSD que suporta —
  # e o disko agora o declara EXPLICITAMENTE (não depender de default do kernel
  # é o que torna seguro desligar o timer). Async discard É a mesma operação do
  # fstrim, só que enfileirada pelo btrfs à medida que extents são liberados, com
  # rate limit. Manter o fstrim.timer junto é re-TRIMar em rajada semanal faixa
  # que já foi trimada — trabalho duplicado, sem ganho.
  # Se algum dia tirar o discard=async do disko, RELIGUE isto no mesmo commit.
  services.fstrim.enable = false;

  # ═══ NOCOW nos bancos de dados ════════════════════════════════════════════
  # CoW + escrita aleatória de 8 KiB (que é o que um banco faz) = fragmentação
  # que só piora. `+C` no DIRETÓRIO faz todo arquivo NOVO nascer nodatacow.
  #
  # DOIS avisos honestos:
  #   • Arquivo que JÁ existe não é convertido (o chattr +C falha em arquivo com
  #     extents). Converter de verdade exige copiar pra um diretório novo já com
  #     +C e trocar — invasivo demais pra automatizar aqui, e o ganho no tamanho
  #     atual destes bancos não paga o risco.
  #   • nodatacow também desliga o CHECKSUM desses arquivos. É trade-off
  #     consciente: Postgres tem checksum próprio, e o SQLite do Jellyfin é
  #     reconstruível varrendo a biblioteca de novo.
  systemd.tmpfiles.rules = [
    "h /var/lib/docker/volumes - - - - +C" # volumes de container (o Postgres do duo mora aqui)
    "h /var/lib/jellyfin/data  - - - - +C" # SQLite da biblioteca do Jellyfin
  ];
}
