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

# 0) Sanidade: o binário em uso precisa ter o plugin da Cloudflare, senão o
#    Caddy se recusa a subir (DNS-01 challenge do curinga *.v1cferr.dev).
#    O binário custom mora em /usr/local/bin/caddy (ver scripts/caddy/build.sh);
#    a unit aponta pra lá via exec.conf. Se faltar, mande buildar primeiro.
CADDY_BIN="/usr/local/bin/caddy"
if [[ ! -x "${CADDY_BIN}" ]] || ! "${CADDY_BIN}" list-modules 2>/dev/null | grep -q '^dns.providers.cloudflare$'; then
    echo "[deploy] ERRO: ${CADDY_BIN} ausente ou sem dns.providers.cloudflare." >&2
    echo "[deploy] Rode primeiro (SEM sudo): ~/dotfiles/scripts/caddy/build.sh" >&2
    exit 1
fi

# 1) Caddyfile + drop-ins do systemd (env = token CF; exec = binário custom)
install -Dm0644 "${CADDY_PKG}/etc/caddy/Caddyfile" /etc/caddy/Caddyfile
install -Dm0644 "${CADDY_PKG}/etc/systemd/system/caddy.service.d/env.conf" \
                /etc/systemd/system/caddy.service.d/env.conf
install -Dm0644 "${CADDY_PKG}/etc/systemd/system/caddy.service.d/exec.conf" \
                /etc/systemd/system/caddy.service.d/exec.conf
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
