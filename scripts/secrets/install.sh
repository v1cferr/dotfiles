#!/usr/bin/env bash
# ============================================================================
#  Instala e ativa o timer (de USUÁRIO) do backup de segredos (diário)
# ----------------------------------------------------------------------------
#  Precisa da passphrase em ~/.config/secrets-backup.passphrase (a MESMA usada
#  no backup) para rodar sem prompt. NÃO use sudo (é timer de usuário).
#
#  Uso:  ~/dotfiles/scripts/secrets/install.sh
# ============================================================================
set -euo pipefail
if [[ ${EUID} -eq 0 ]]; then echo "NÃO use sudo — é timer de usuário." >&2; exit 1; fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PASS_FILE="${HOME}/.config/secrets-backup.passphrase"

if [[ ! -f "${PASS_FILE}" ]]; then
    echo "Falta a passphrase para o backup rodar automático (sem prompt)."
    echo "Crie com a MESMA passphrase que você usa no backup:"
    echo
    echo "  umask 077; printf '%s' 'SUA_PASSPHRASE' > '${PASS_FILE}'"
    echo
    echo "(o arquivo fica fora do repo e fora do próprio backup). Depois rode este script de novo."
    exit 1
fi
chmod 600 "${PASS_FILE}"

UNIT_DIR="${HOME}/.config/systemd/user"
install -Dm0644 "${SCRIPT_DIR}/dotfiles-secrets-backup.service" "${UNIT_DIR}/dotfiles-secrets-backup.service"
install -Dm0644 "${SCRIPT_DIR}/dotfiles-secrets-backup.timer"   "${UNIT_DIR}/dotfiles-secrets-backup.timer"
systemctl --user daemon-reload
systemctl --user enable --now dotfiles-secrets-backup.timer
echo "[install] timer ativado; gerando o backup agora:"
"${SCRIPT_DIR}/backup.sh"
systemctl --user list-timers dotfiles-secrets-backup.timer --no-pager || true
