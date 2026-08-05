# ═══════════════════════════════════════════════════════════════════════════
# BACKUP DECLARATIVO (restic) — estado do usuário → repositório CIFRADO.
#
# restic cifra tudo em repouso e guarda com checksum (o `restic check` verifica
# integridade — o mesmo padrão que se quer pra armazenamento "duvidoso").
#
# PAR COM O btrbk (btrbk.nix): o snapshot local horário cobre "sobrescrevi agora há
# pouco"; ESTE cobre "o disco morreu". Snapshot no mesmo disco não é backup.
#
# A senha do repo é SEGREDO (sops: restic_password) — a MESMA nos dois destinos, de
# propósito: repos intercambiáveis na restauração.
#
# ── TRANSIÇÃO EM CURSO (05/08/2026): Seagate → Google Drive ─────────────────
# DESTINO: ficar só com o Drive. O motivo não é espaço (Drive tem 4,95 TiB livres de
# 5 TiB) — é que a única cópia do home vivo estava num Momentus 7200.4 de ~2009, com
# 840 mil load cycles (40% além do spec) e 348 erros de CRC, DENTRO da máquina. Uma
# cópia offsite ganha nos modos de falha que de fato acontecem: disco morre, roubo,
# incêndio. Perde em velocidade de restauração e passa a depender da conta Google.
#
# OS DOIS RODAM enquanto a transição não fecha — e essa ordem NÃO é negociável:
#   1. `home-gdrive` faz o primeiro backup completo (demora: é upload de ~dezenas de GB);
#   2. `sudo restic-home-gdrive check --read-data` passa;
#   3. SÓ ENTÃO apagar o alvo `home` daqui e o repo do Seagate.
# Destruir a cópia velha antes da nova estar VERIFICADA é como se perde backup.
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # SSOT dos dois destinos (regra 11): fonte, exclusões e retenção não podem existir
  # duplicadas — duas listas divergem em silêncio e aí os repos param de ser
  # intercambiáveis, que é justamente a propriedade que os torna redundância.
  comum = {
    passwordFile = config.sops.secrets.restic_password.path;
    initialize = true; # cria o repo no 1º backup

    paths = [ "/home/v1cferr" ];

    # exclui o regenerável (cache/build/lixo). O `storage` do Zen (dados de site)
    # NÃO é cache → fica; só o cache2 (http cache do Firefox/Zen) sai.
    exclude = [
      "/home/v1cferr/.cache"
      "/home/v1cferr/.local/share/Trash"
      # ── Volumosos e RE-OBTENÍVEIS (não faz sentido cifrar/guardar) ──
      "/home/v1cferr/Downloads" # transiente
      "/home/v1cferr/Games" # jogos (PS3 etc.) — re-baixáveis das fontes
      "/home/v1cferr/.local/share/bottles" # prefixos Wine (~154G): jogos re-instaláveis. NOTA: saves de jogo vivem aqui dentro — se algum for insubstituível, faça backup à parte.
      "/home/v1cferr/.local/share/Steam" # biblioteca Steam, se houver (re-baixável)
      "**/node_modules"
      "**/.direnv"
      "**/target" # builds Rust
      "**/__pycache__"
      "**/.venv"
      "**/Cache"
      "**/Cache_Data"
      "**/CachedData"
      "**/Code Cache"
      "**/GPUCache"
      "**/ShaderCache"
      "**/cache2" # http cache do Firefox/Zen (mantém o 'storage')
      "**/startupCache"
    ];

    # retenção: poda automática após cada backup
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };
in
lib.mkIf config.my.services.restic {
  # ── DESTINO ANTIGO: HDD Seagate (sai quando o Drive estiver verificado) ─────
  # SEGURANÇA: o backup só roda com o HDD montado. Sem isto, se o disco não montasse,
  # o restic gravaria em /mnt/seagate-old na RAIZ do NVMe — backup no lugar errado +
  # enchendo o disco que a gente quer aliviar. RequiresMountsFor barra isso.
  systemd.services.restic-backups-home.unitConfig.RequiresMountsFor = "/mnt/seagate-old";

  services.restic.backups.home = comum // {
    repository = "/mnt/seagate-old/restic";

    timerConfig = {
      OnCalendar = "daily";
      Persistent = true; # roda no boot se perdeu o horário
      RandomizedDelaySec = "15min";
    };

    # integridade: relê 10% dos dados a cada run. Barato em disco LOCAL; é justamente
    # o que NÃO se faz no destino remoto (ver lá embaixo).
    checkOpts = [ "--read-data-subset=10%" ];
  };

  # ── DESTINO NOVO: Google Drive, OFFSITE ────────────────────────────────────
  # PEGADINHA que já custou o serviço do arquivo do Arch: o módulo do nixpkgs põe SÓ o
  # ssh no PATH (`path = [ config.programs.ssh.package ]`), e o backend `rclone:` do
  # restic EXECUTA o binário rclone. Sem este mkAfter, morre na largada com
  # "rclone: executable file not found in $PATH".
  systemd.services.restic-backups-home-gdrive.path = lib.mkAfter [ pkgs.rclone ];

  services.restic.backups.home-gdrive = comum // {
    # `rclone:<remote>:<caminho>` — o restic sobe um `rclone rcd` e fala HTTP com ele.
    # O caminho nomeia a MÁQUINA (placa EX-B560M-V5) pra conviver com outros backups lá.
    repository = "rclone:gdrive:BACKUPS_EX-B560M-V5/HOME";

    # rclone.conf com o token OAuth = SEGREDO (regra 12). NUNCA a opção `rcloneConfig`
    # (attrset): ela vaza o token pro /nix/store, que é world-readable.
    rcloneConfigFile = config.sops.secrets.rclone_gdrive_conf.path;

    # Uma hora DEPOIS do destino local: os dois leem os mesmos 2,9 M de arquivos, e
    # rodar junto brigaria por I/O no mesmo home sem ganho nenhum.
    timerConfig = {
      OnCalendar = "03:00";
      Persistent = true;
      RandomizedDelaySec = "30min";
    };

    extraBackupArgs = [
      # A opção que decide a VIABILIDADE (não é otimização): no Drive o custo é por
      # CHAMADA de API, não por byte. São 2,9 MILHÕES de arquivos aqui — em objetos de
      # 128 MiB (o máximo do restic) isso vira alguns milhares de objetos. Medido no
      # arquivo do Arch: 44,6 GiB viraram 189 packs.
      "--pack-size=128"
      "--one-file-system" # não atravessa pra outro FS se aparecer mount aninhado
      "--exclude-caches" # pula diretório com CACHEDIR.TAG (padrão freedesktop)
    ];

    # Progresso 1x/min no journal. No default (1 fps) o upload longo viraria milhares
    # de linhas.
    progressFps = 0.0167;

    # `--read-data-subset` fica FORA de propósito: relê = BAIXA. 10% por dia de um repo
    # de dezenas de GB seria vários GB de download diário, todo dia, pra sempre. Aqui o
    # check é só de ESTRUTURA (índices/árvores), que é metadado e sai barato; a leitura
    # integral dos dados é MANUAL e deliberada:
    #   sudo restic-home-gdrive check --read-data
    checkOpts = [ ];

    # Poda em repo remoto REEMPACOTA: baixa packs parcialmente usados e sobe de volta.
    # Sem limite, um prune ruim viraria horas de tráfego. O teto por execução mantém o
    # custo previsível — o que não couber hoje é podado na próxima.
    pruneOpts = comum.pruneOpts ++ [ "--max-repack-size=2G" ];
  };
}
