#!/usr/bin/env bash
# ============================================================================
#  Deploy do Caddy para o sistema (/etc)
# ----------------------------------------------------------------------------
#  Copia o Caddyfile e o drop-in do systemd dos dotfiles para /etc, recarrega
#  o systemd e (re)inicia o serviço. Precisa de root.
#
#  Por que este script existe: o stow-sync aponta para $HOME, então não serve
#  para /etc. E os caminhos aqui são resolvidos a partir da LOCALIZAÇÃO do
#  script (não de ~), então rodar com sudo NÃO cai na pegadinha do ~ -> /root.
#
#  Uso:  sudo ~/dotfiles/scripts/caddy/deploy.sh
# ============================================================================
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Este script precisa de root. Rode: sudo $0" >&2
    exit 1
fi

# Raiz do repo: este arquivo fica em <repo>/scripts/caddy/deploy.sh
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CADDY_PKG="${DOTFILES_DIR}/caddy"

echo "[deploy] dotfiles: ${DOTFILES_DIR}"

# 1) Caddyfile + drop-in do systemd
install -Dm0644 "${CADDY_PKG}/etc/caddy/Caddyfile" /etc/caddy/Caddyfile
install -Dm0644 "${CADDY_PKG}/etc/systemd/system/caddy.service.d/env.conf" \
                /etc/systemd/system/caddy.service.d/env.conf
echo "[deploy] arquivos copiados para /etc"

# 2) Recarrega o systemd (drop-in pode ter mudado) e sobe/reinicia o caddy.
#    Restart (não reload) porque mudanças no EnvironmentFile só valem em start.
systemctl daemon-reload
if systemctl is-enabled --quiet caddy 2>/dev/null; then
    systemctl restart caddy
else
    systemctl enable --now caddy
fi

echo "[deploy] ok — status:"
systemctl --no-pager --full status caddy | head -n 10
