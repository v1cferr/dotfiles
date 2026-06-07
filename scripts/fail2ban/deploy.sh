#!/usr/bin/env bash
# ============================================================================
#  Deploy do fail2ban para o sistema (/etc)
# ----------------------------------------------------------------------------
#  Copia TUDO de fail2ban/etc/ (jails em jail.d/, filtros em filter.d/) para
#  /etc preservando a estrutura, e recarrega o fail2ban. Precisa de root.
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

# Copia cada arquivo de fail2ban/etc/... para /etc/... (jail.d, filter.d, etc.)
while IFS= read -r -d '' src; do
    dest="/etc/${src#"${PKG}/etc/"}"
    install -Dm0644 "${src}" "${dest}"
    echo "[deploy] ${dest}"
done < <(find "${PKG}/etc" -type f -print0)

# Restart (não só reload) para garantir que jails novas com backend systemd
# subam corretamente.
systemctl restart fail2ban
echo "[deploy] fail2ban reiniciado. Jails ativas:"
sleep 1
fail2ban-client status 2>/dev/null | sed 's/^/  /' || \
    echo "  (rode 'sudo fail2ban-client status' em instantes; o socket pode levar 1s)"
