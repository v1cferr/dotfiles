# ═══════════════════════════════════════════════════════════════════════════
# BACKUP DECLARATIVO (restic) — estado do usuário → repositório CIFRADO.
#
# restic cifra tudo em repouso e guarda com checksum (o `restic check` verifica
# integridade — o mesmo padrão que se quer pra armazenamento "duvidoso").
#
# Repo no HDD Seagate (/mnt/seagate-old/restic), OFF-DISK: o NixOS roda do SanDisk
# (SSD SATA) e o backup vai pro HDD SEPARADO → sobrevive à morte do SanDisk (backup
# de verdade, não só snapshot). O SanDisk não carrega cópia nenhuma. ext4 nos dois →
# sem snapshot CoW "grátis"; pra isso, formatar em btrfs numa migração futura.
#
# A senha do repo é SEGREDO (sops: restic_password). Sem ela não decripta o repo.
# ═══════════════════════════════════════════════════════════════════════════
{ config, ... }:

{
  # SEGURANÇA: o backup só roda com o HDD Seagate montado. Sem isto, se o disco não
  # montasse, o restic gravaria em /mnt/seagate-old na RAIZ (SanDisk) — backup no
  # lugar errado + enchendo o disco que a gente quer aliviar. RequiresMountsFor barra isso.
  systemd.services.restic-backups-home.unitConfig.RequiresMountsFor = "/mnt/seagate-old";

  services.restic.backups.home = {
    repository = "/mnt/seagate-old/restic"; # HDD Seagate, off-disk (ver cabeçalho)
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

    # todo dia, com atraso aleatório; roda no boot se perdeu o horário
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "15min";
    };

    # retenção: poda automática após cada backup
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];

    # integridade: verifica 10% dos dados a cada run (o "checksum" automático)
    checkOpts = [ "--read-data-subset=10%" ];
  };
}
