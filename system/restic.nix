# ═══════════════════════════════════════════════════════════════════════════
# BACKUP DECLARATIVO (restic) — estado do usuário → repositório CIFRADO.
#
# restic cifra tudo em repouso e guarda com checksum (o `restic check` verifica
# integridade — o mesmo padrão que se quer pra armazenamento "duvidoso").
#
# Repo AGORA no HDD (/var/backup/restic): como o NixOS roda do HDD, é HDD→HDD —
# dá snapshots + cifra + serve de VEÍCULO de migração (restore no destino), mas
# NÃO protege contra falha do próprio HDD. Pós-cutover (NixOS no SanDisk), muda
# o `repository` pro HDD montado (ex.: /mnt/hdd-backup/restic) → aí é backup
# off-disk de verdade (SanDisk→HDD).
#
# A senha do repo é SEGREDO (sops: restic_password). Sem ela não decripta o repo.
# ═══════════════════════════════════════════════════════════════════════════
{ config, ... }:

{
  # garante o diretório-pai do repo (restic init cria o repo, não o /var/backup)
  systemd.tmpfiles.rules = [ "d /var/backup 0700 root root -" ];

  services.restic.backups.home = {
    repository = "/var/backup/restic"; # HDD por ora (ver cabeçalho)
    passwordFile = config.sops.secrets.restic_password.path;
    initialize = true; # cria o repo no 1º backup

    paths = [ "/home/v1cferr" ];

    # exclui o regenerável (cache/build/lixo). O `storage` do Zen (dados de site)
    # NÃO é cache → fica; só o cache2 (http cache do Firefox/Zen) sai.
    exclude = [
      "/home/v1cferr/.cache"
      "/home/v1cferr/.local/share/Trash"
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
