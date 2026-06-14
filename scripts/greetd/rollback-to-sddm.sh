#!/usr/bin/env bash
# ============================================================================
#  Rollback: greetd -> SDDM  (válido enquanto o SDDM não foi removido)
# ----------------------------------------------------------------------------
#  Reversão instantânea se o greeter falhar. Pode rodar via SSH/console.
#
#  Uso:  sudo ~/dotfiles/scripts/greetd/rollback-to-sddm.sh && sudo reboot
# ============================================================================
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Precisa de root. Rode: sudo $0" >&2
    exit 1
fi

if ! command -v sddm >/dev/null 2>&1; then
    echo "ERRO: SDDM não está mais instalado — rollback impossível." >&2
    echo "      Reinstale:  sudo pacman -S sddm && sudo ~/dotfiles/scripts/sddm/deploy.sh" >&2
    exit 1
fi

echo "[rollback] parando/desabilitando greetd e voltando pro sddm…"
systemctl stop greetd.service 2>/dev/null || true
systemctl disable greetd.service 2>/dev/null || true
systemctl enable sddm.service

echo "[rollback] feito. Reinicie:  sudo reboot"
