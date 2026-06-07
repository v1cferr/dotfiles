#!/usr/bin/env bash
# ============================================================================
#  Deploy do Cloudflare DDNS para o sistema (/etc)
# ----------------------------------------------------------------------------
#  Instala as units systemd (service + timer) do atualizador de DNS dinâmico,
#  resolvendo o caminho do projeto (placeholder __DDNS_DIR__) para a cópia
#  versionada nos dotfiles. O worker e o config ficam em cloudflare-ddns/.
#
#  Mesmo motivo do caddy/fail2ban: o stow-sync aponta pro $HOME e não cobre
#  /etc. Os caminhos são resolvidos pela LOCALIZAÇÃO do script, então rodar
#  com sudo NÃO cai na pegadinha do ~ -> /root.
#
#  Pré-requisito: criar cloudflare-ddns/config/.env a partir de .env.example
#  (com o seu token — esse arquivo é gitignored).
#
#  Uso:  sudo ~/dotfiles/scripts/cloudflare-ddns/deploy.sh
# ============================================================================
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Este script precisa de root. Rode: sudo $0" >&2
    exit 1
fi

# Raiz do repo: este arquivo fica em <repo>/scripts/cloudflare-ddns/deploy.sh
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PKG="${DOTFILES_DIR}/cloudflare-ddns"

echo "[deploy] dotfiles: ${DOTFILES_DIR}"

# 1) Pré-requisito: o .env centralizado (root dos dotfiles) precisa existir (gitignored)
if [[ ! -f "${DOTFILES_DIR}/.env" ]]; then
    echo "ERRO: ${DOTFILES_DIR}/.env não encontrado." >&2
    echo "      Crie a partir do modelo: cp ${DOTFILES_DIR}/.env.example ${DOTFILES_DIR}/.env" >&2
    echo "      e preencha API_TOKEN/ZONE_ID/RECORD_ID/RECORD_NAME." >&2
    exit 1
fi

# 2) Garante worker executável e diretório de logs
chmod +x "${PKG}/bin/cloudflare-ddns.sh"
install -d -m 0755 "${PKG}/logs"

# 3) Instala as units resolvendo __DDNS_DIR__ -> caminho real do projeto
for unit in cloudflare-ddns.service cloudflare-ddns.timer; do
    sed "s|__DDNS_DIR__|${PKG}|g" "${PKG}/etc/systemd/system/${unit}" \
        > "/etc/systemd/system/${unit}"
    chmod 0644 "/etc/systemd/system/${unit}"
    echo "[deploy] /etc/systemd/system/${unit}"
done

# 4) Recarrega e ativa o timer
systemctl daemon-reload
systemctl enable --now cloudflare-ddns.timer

echo "[deploy] ok — timer:"
systemctl --no-pager status cloudflare-ddns.timer | head -n 6 || true
