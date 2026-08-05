# ═══════════════════════════════════════════════════════════════════════════
# ~/Drive ⇄ Google Drive — pasta SINCRONIZADA (estilo Dropbox), via rclone bisync.
#
# NÃO É BACKUP, e a diferença importa: sync PROPAGA. Apagar aqui apaga lá (é o
# objetivo), então isto não substitui o restic (system/services/restic.nix) nem a
# regra 6. A rede de segurança de um sync é a lixeira do Drive (30 dias), não versão.
#
# ── POR QUE UMA PASTA DEDICADA E NÃO A RAIZ DO DRIVE ────────────────────────
# A raiz tem `BACKUPS_EX-B560M-V5/` com os repos restic — ~48 GiB de blob cifrado.
# Sincronizar a raiz baixaria isso pro disco local, o que (a) enche o NVMe, (b) mata
# a propriedade que faz o backup ser OFFSITE, e (c) põe o repo no caminho de um
# comando que apaga em duas pontas. O `filters` abaixo exclui esse diretório de
# qualquer forma, pra que apontar `my.drive.remote` pra raiz um dia não seja fatal.
#
# ── PRIMEIRO USO: MANUAL, UMA VEZ (não dá pra automatizar) ──────────────────
# O bisync exige um `--resync` inicial pra criar a linha-base das duas listagens.
# Sem ela o serviço FALHA de propósito, em vez de adivinhar quem é a verdade.
#   1. ENSAIO — leia a saída inteira antes de continuar:
#        rclone --config /run/secrets/rclone_gdrive_conf bisync \
#          ~/Drive gdrive:Drive --resync --dry-run -v
#   2. VALENDO (sem --check-access: o RCLONE_TEST remoto só nasce agora, propagado
#      pelo próprio resync):
#        rclone --config /run/secrets/rclone_gdrive_conf bisync \
#          ~/Drive gdrive:Drive --resync -v
#   3. Daí em diante o timer cuida, e `--resync` NUNCA mais — repetir impede
#      deleção (arquivo apagado ressuscita do outro lado).
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.drive;

  # Filtros do bisync. Sintaxe: `- <padrão>` exclui. Caminho começando em `/` é
  # relativo à RAIZ do sync, não ao filesystem.
  filters = pkgs.writeText "drive-bisync-filters.txt" ''
    - /BACKUPS_EX-B560M-V5/**
    - .DS_Store
    - *~
    - .Trash-*/**
  '';
in
{
  options.my.drive = {
    local = lib.mkOption {
      type = lib.types.str;
      default = "/home/v1cferr/Drive";
      description = "Pasta local sincronizada. Lida também pelo bookmark do Dolphin (SSOT, regra 11).";
    };
    remote = lib.mkOption {
      type = lib.types.str;
      default = "gdrive:Drive";
      description = "Destino no formato `<remote>:<caminho>`. O remote vem do rclone.conf do sops.";
    };
  };

  config = lib.mkIf osConfig.my.services.drive-sync {
    systemd.user.services.drive-bisync = {
      Unit.Description = "Sincroniza ${cfg.local} com ${cfg.remote} (rclone bisync)";

      Service = {
        Type = "oneshot";

        # O rclone.conf do Drive tem o token OAuth e é do SOPS. Aponta o RCLONE_CONFIG
        # SÓ nesta unit, e NÃO no ambiente global: o `programs.rclone` (home-manager)
        # gera o próprio rclone.conf pro remote `faiws`, e exportar isto pra sessão
        # inteira faria o mount da FAI procurar o remote no arquivo errado.
        Environment = "RCLONE_CONFIG=/run/secrets/rclone_gdrive_conf";

        # `--check-access` compara um arquivo RCLONE_TEST nos DOIS lados e ABORTA se
        # faltar. É a proteção contra o desastre clássico do sync bidirecional: um lado
        # aparece vazio (rede caiu, pasta não montou) e a ferramenta "sincroniza" isso
        # apagando o outro. O marcador local é criado aqui; o remoto nasce no resync.
        ExecStartPre = [
          "${pkgs.coreutils}/bin/mkdir -p ${cfg.local}"
          "${pkgs.coreutils}/bin/touch ${cfg.local}/RCLONE_TEST"
        ];

        ExecStart = lib.concatStringsSep " " [
          "${pkgs.rclone}/bin/rclone bisync"
          cfg.local
          cfg.remote
          "--filters-file ${filters}"
          "--check-access" # aborta se o RCLONE_TEST faltar de um lado (ver acima)
          "--max-delete 10" # aborta se >10% dos arquivos forem deleção (default é 50%)
          "--conflict-resolve newer" # editou nos dois lados? o mais recente vence
          "--conflict-loser num" # o perdedor é RENOMEADO, não apagado
          "--resilient" # erro leve não exige resync manual (feito p/ rodar sozinho)
          "--recover" # retoma de interrupção usando a listagem de backup
          "--max-lock 2m" # renova o lock; run travado não bloqueia o próximo p/ sempre
          # Google Docs não tem tamanho nem checksum (exportam como -1), então não
          # sincronizam de forma sã. Ficam FORA; para abri-los, o Drive na web.
          "--drive-skip-gdocs"
          "-v" # o journal é o log (journalctl --user -u drive-bisync)
        ];
      };
    };

    # A cada 15 min. Não é "tempo real" como o Dropbox — bisync é em lote, compara as
    # duas listagens a cada execução. 15 min é o meio entre latência aceitável e não
    # torrar chamada de API (no Drive o custo é por chamada).
    systemd.user.timers.drive-bisync = {
      Unit.Description = "Timer do bisync ${cfg.local} ⇄ ${cfg.remote}";
      Timer = {
        OnCalendar = "*:0/15";
        Persistent = true; # roda no login se perdeu a janela
        RandomizedDelaySec = "1m";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
