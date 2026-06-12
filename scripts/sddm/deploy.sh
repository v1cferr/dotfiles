#!/usr/bin/env bash
# ============================================================================
#  Deploy do SDDM para o sistema (/etc + /usr/share)
# ----------------------------------------------------------------------------
#  Copia o tema tokyo-night-sddm (clonado, não vem de pacote) e a config do
#  SDDM dos dotfiles para o sistema. Precisa de root.
#
#  NÃO reinicia o sddm de propósito: reiniciar derruba a sessão atual.
#  As mudanças aparecem no próximo logout/boot.
#
#  Uso:  sudo ~/dotfiles/scripts/sddm/deploy.sh
# ============================================================================
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Este script precisa de root. Rode: sudo $0" >&2
    exit 1
fi

# Raiz do repo: este arquivo fica em <repo>/scripts/sddm/deploy.sh
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DOTFILES_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SDDM_PKG="${DOTFILES_DIR}/sddm"

echo "[deploy] dotfiles: ${DOTFILES_DIR}"

# 1) Tema completo (-T: copia o CONTEÚDO por cima, sem aninhar diretório)
mkdir -p /usr/share/sddm/themes
cp -rT "${SDDM_PKG}/usr/share/sddm/themes/tokyo-night-sddm" \
       /usr/share/sddm/themes/tokyo-night-sddm
echo "[deploy] tema tokyo-night-sddm copiado para /usr/share/sddm/themes"

# 2) Config do SDDM (qual tema usar)
install -Dm0644 "${SDDM_PKG}/etc/sddm.conf.d/theme.conf" /etc/sddm.conf.d/theme.conf
echo "[deploy] /etc/sddm.conf.d/theme.conf atualizado"

echo "[deploy] ok — o visual novo aparece no próximo logout (sddm não foi reiniciado)"
