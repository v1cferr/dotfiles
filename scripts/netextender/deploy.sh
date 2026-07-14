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
    case "${dest}" in
        /etc/sudoers.d/*)
            # sudoers exige 0440 e sintaxe válida — instala num temp, valida, move
            install -Dm0440 "${src}" "${dest}.tmp"
            if visudo -cf "${dest}.tmp" >/dev/null; then
                mv -f "${dest}.tmp" "${dest}"
                echo "[deploy] ${dest} (0440, validado)"
            else
                rm -f "${dest}.tmp"
                echo "ERRO: sudoers inválido, não instalei: ${dest}" >&2; exit 1
            fi
            ;;
        *)
            install -Dm0644 "${src}" "${dest}"
            echo "[deploy] ${dest}"
            ;;
    esac
done < <(find "${PKG}/etc" -type f -print0)

# Aplica o sysctl do VPN gateway (ip_forward) sem precisar de reboot.
if [[ -f /etc/sysctl.d/99-fai-vpn-gateway.conf ]]; then
    sysctl -p /etc/sysctl.d/99-fai-vpn-gateway.conf >/dev/null && \
        echo "[deploy] sysctl aplicado (net.ipv4.ip_forward)"
fi

echo "[deploy] perfil instalado. Confirme que o seu NetExtender lê de /etc/SonicWall/."
