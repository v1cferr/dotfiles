#!/usr/bin/env bash
# ============================================================================
#  Instala e ativa o timer (de USUÁRIO) que regenera as listas de pacotes
# ----------------------------------------------------------------------------
#  Copia as units para ~/.config/systemd/user/, recarrega e ativa o timer
#  (a cada 5min). Roda uma vez na hora pra já gerar as listas.
#
#  NÃO use sudo: é um timer de usuário (roda como você, sem root).
#
#  Uso:  ~/dotfiles/scripts/packages/install.sh
# ============================================================================
set -euo pipefail

if [[ ${EUID} -eq 0 ]]; then
    echo "NÃO rode como root — é um timer de usuário. Rode sem sudo: $0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
UNIT_DIR="${HOME}/.config/systemd/user"

install -Dm0644 "${SCRIPT_DIR}/dotfiles-pkgsync.service" "${UNIT_DIR}/dotfiles-pkgsync.service"
install -Dm0644 "${SCRIPT_DIR}/dotfiles-pkgsync.timer"   "${UNIT_DIR}/dotfiles-pkgsync.timer"
echo "[install] units copiadas para ${UNIT_DIR}"

systemctl --user daemon-reload
systemctl --user enable --now dotfiles-pkgsync.timer
echo "[install] timer ativado"

# Gera as listas já agora
"${SCRIPT_DIR}/sync.sh"
echo "[install] listas geradas:"
wc -l "${SCRIPT_DIR}"/pacman-explicit.txt "${SCRIPT_DIR}"/aur.txt "${SCRIPT_DIR}"/orphans.txt 2>/dev/null || true

echo "[install] próximas execuções:"
systemctl --user list-timers dotfiles-pkgsync.timer --no-pager || true
