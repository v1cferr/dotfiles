#!/usr/bin/env bash
# ============================================================================
#  Deploy de configs base do sistema: pacman + makepkg
# ----------------------------------------------------------------------------
#  Instala pacman.conf, o hook custom e makepkg.conf (+ drop-ins). NÃO aplica
#  mkinitcpio.conf nem /boot/loader — esses são versionados só como REFERÊNCIA
#  (aplicar errado pode quebrar o boot; veja system/README.md).
#
#  Uso:  sudo ~/dotfiles/scripts/system/deploy.sh
# ============================================================================
set -euo pipefail
if [[ ${EUID} -ne 0 ]]; then echo "Precisa de root. Rode: sudo $0" >&2; exit 1; fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PKG="${DOTFILES_DIR}/system"

# Valida o pacman.conf antes de sobrescrever o do sistema
if command -v pacman-conf >/dev/null 2>&1; then
    pacman-conf --config "${PKG}/etc/pacman.conf" >/dev/null \
        || { echo "ERRO: pacman.conf inválido." >&2; exit 1; }
fi

install -Dm0644 "${PKG}/etc/pacman.conf" /etc/pacman.conf
install -Dm0644 "${PKG}/etc/pacman.d/hooks/fix-appstream-data.hook" \
                /etc/pacman.d/hooks/fix-appstream-data.hook
install -Dm0644 "${PKG}/etc/makepkg.conf" /etc/makepkg.conf
for f in "${PKG}"/etc/makepkg.conf.d/*.conf; do
    [[ -e "$f" ]] || continue
    install -Dm0644 "$f" "/etc/makepkg.conf.d/$(basename "$f")"
done
echo "[deploy] pacman.conf + hook + makepkg.conf(.d) instalados"
echo "[deploy] mkinitcpio.conf e boot/ NÃO foram aplicados (são referência)"
