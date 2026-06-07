#!/usr/bin/env bash
# ============================================================================
#  Deploy do perfil SonicWall NetExtender para o sistema (/etc)
# ----------------------------------------------------------------------------
#  Copia o perfil de VPN (etc/SonicWall/...) para /etc. NÃO é stow: o pacote
#  netextender/ tem estrutura de /etc, então stowar criaria um ~/etc errado.
#  Caminhos resolvidos pela LOCALIZAÇÃO do script (sudo não cai na pegadinha
#  do ~ -> /root).
#
#  Uso:  sudo ~/dotfiles/scripts/netextender/deploy.sh
# ============================================================================
set -euo pipefail
if [[ ${EUID} -ne 0 ]]; then echo "Precisa de root. Rode: sudo $0" >&2; exit 1; fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PKG="${DOTFILES_DIR}/netextender"

while IFS= read -r -d '' src; do
    dest="/etc/${src#"${PKG}/etc/"}"
    install -Dm0644 "${src}" "${dest}"
    echo "[deploy] ${dest}"
done < <(find "${PKG}/etc" -type f -print0)

echo "[deploy] perfil instalado. Confirme que o seu NetExtender lê de /etc/SonicWall/."
