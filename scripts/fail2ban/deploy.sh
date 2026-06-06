#!/usr/bin/env bash
# ============================================================================
#  Deploy do fail2ban para o sistema (/etc)
# ----------------------------------------------------------------------------
#  Copia a jail dos dotfiles para /etc/fail2ban/jail.d/ e recarrega o
#  fail2ban. Precisa de root.
#
#  Mesmo motivo do deploy do Caddy: o stow-sync aponta pro $HOME e não cobre
#  /etc. Os caminhos são resolvidos pela LOCALIZAÇÃO do script, então rodar
#  com sudo NÃO cai na pegadinha do ~ -> /root.
#
#  Uso:  sudo ~/dotfiles/scripts/fail2ban/deploy.sh
# ============================================================================
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Este script precisa de root. Rode: sudo $0" >&2
    exit 1
fi

# Raiz do repo: este arquivo fica em <repo>/scripts/fail2ban/deploy.sh
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PKG="${DOTFILES_DIR}/fail2ban"

install -Dm0644 "${PKG}/etc/fail2ban/jail.d/sshd.local" /etc/fail2ban/jail.d/sshd.local
echo "[deploy] jail.d/sshd.local copiado para /etc"

# reload re-lê o jail.d; se falhar, restart.
systemctl reload fail2ban 2>/dev/null || systemctl restart fail2ban
echo "[deploy] fail2ban recarregado — status da jail sshd:"
fail2ban-client status sshd 2>/dev/null | head -n 12 || \
    echo "  (rode 'sudo fail2ban-client status sshd' em instantes; o socket pode levar 1s)"
