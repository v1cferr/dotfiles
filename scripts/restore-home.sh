#!/usr/bin/env bash
# Restaura o ~ do backup restic (repo no HDD Seagate, que segue plugado).
# Rodar JÁ NA SANDISK, de um TTY (não logado no desktop), como root:
#   sudo ./scripts/restore-home.sh
set -euo pipefail

SEAGATE="/dev/disk/by-id/ata-ST9320423AS_5VH4YZV8-part2"
MNT="/mnt/seagate"

[ -e "$SEAGATE" ] || { echo "ERRO: raiz do Seagate não encontrada ($SEAGATE). Veja 'lsblk -f' e ajuste o by-id."; exit 1; }
[ -r /run/secrets/restic_password ] || { echo "ERRO: /run/secrets/restic_password ausente (sops não decriptou?)."; exit 1; }

mkdir -p "$MNT"
mountpoint -q "$MNT" || mount -o ro "$SEAGATE" "$MNT"

echo "==> restaurando o snapshot mais recente do restic pra /home…"
nix shell nixpkgs#restic --command restic \
  -r "$MNT/var/backup/restic" \
  --password-file /run/secrets/restic_password \
  restore latest --target /

umount "$MNT" 2>/dev/null || true
echo
echo "✅ ~ restaurado. Falta só re-parear o fone:"
echo "   bluetoothctl → scan on / pair <MAC> / trust <MAC> / connect <MAC>"
