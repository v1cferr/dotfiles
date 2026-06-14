#!/usr/bin/env bash
# ============================================================================
#  Instala e ativa o timer (de USUÁRIO) do verificador de malware da AUR
# ----------------------------------------------------------------------------
#  Copia as units para ~/.config/systemd/user/, recarrega e ativa o timer
#  (semanal). Roda uma checagem na hora para validar.
#
#  NÃO use sudo: é um timer de usuário (roda como você, sem root).
#
#  Uso:  ~/dotfiles/scripts/security/install.sh
# ============================================================================
set -euo pipefail

if [[ ${EUID} -eq 0 ]]; then
    echo "NÃO rode como root — é um timer de usuário. Rode sem sudo: $0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
UNIT_DIR="${HOME}/.config/systemd/user"

install -Dm0644 "${SCRIPT_DIR}/dotfiles-aur-malware-check.service" \
    "${UNIT_DIR}/dotfiles-aur-malware-check.service"
install -Dm0644 "${SCRIPT_DIR}/dotfiles-aur-malware-check.timer" \
    "${UNIT_DIR}/dotfiles-aur-malware-check.timer"
echo "[install] units copiadas para ${UNIT_DIR}"

systemctl --user daemon-reload
systemctl --user enable --now dotfiles-aur-malware-check.timer
echo "[install] timer ativado"

echo "[install] rodando uma checagem agora..."
"${SCRIPT_DIR}/aur-malware-check.sh" --refresh || true

echo "[install] próximas execuções:"
systemctl --user list-timers dotfiles-aur-malware-check.timer --no-pager || true
