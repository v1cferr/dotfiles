#!/usr/bin/env bash
# Cutover automático: formata a SanDisk e instala o NixOS (host nixos-sandisk).
# Rodar do LIVE USB, como root, dentro do repo:  sudo ./scripts/cutover-sandisk.sh
set -euo pipefail

HOST="nixos-sandisk"
DISK="/dev/disk/by-id/ata-SanDisk_SSD_PLUS_1000GB_22520C801629"
AGE_ITEM="sops-nix age key (dotfiles)"

# minimal ISO não liga nix-command/flakes por padrão → habilita pra todo nix daqui
export NIX_CONFIG="extra-experimental-features = nix-command flakes"

# segurança: precisa ser o live installer e a SanDisk tem que existir
command -v nixos-install >/dev/null || { echo "Rode isto do LIVE USB do NixOS."; exit 1; }
[ -e "$DISK" ] || { echo "ERRO: SanDisk não encontrada ($DISK). Confira o by-id com 'ls /dev/disk/by-id'."; exit 1; }

echo "⚠️  Vai APAGAR este disco e instalar o NixOS ($HOST):"
lsblk -o NAME,SIZE,MODEL,SERIAL "$DISK" || true
read -rp 'Digite FORMATAR pra confirmar: ' ans
[ "$ans" = "FORMATAR" ] || { echo "Cancelado."; exit 1; }

echo "==> 1/3 disko: particiona + formata + monta a SanDisk em /mnt…"
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode destroy,format,mount --flake ".#$HOST"

echo "==> 2/3 chave age do Bitwarden (login com a senha-mestra)…"
install -d -m 700 /mnt/var/lib/sops-nix
export AGE_ITEM
# shellcheck disable=SC2016  # aspas simples de propósito: o bash INTERNO expande em runtime
nix shell nixpkgs#bitwarden-cli --command bash -c '
  set -euo pipefail
  bw login || true                      # se já logado, segue
  BW_SESSION=$(bw unlock --raw); export BW_SESSION
  bw get notes "$AGE_ITEM" | install -m 600 /dev/stdin /mnt/var/lib/sops-nix/key.txt
'
echo "    chave age instalada em /mnt/var/lib/sops-nix/key.txt"

echo "==> 3/3 nixos-install (a senha do usuário vem do sops)…"
nixos-install --flake ".#$HOST"

echo
echo "✅ Instalado. Rode 'reboot', tire o pendrive e boote na SanDisk (ordem de boot na BIOS)."
echo "   Já logado, restaure seus dados com:  sudo ./scripts/restore-home.sh"
