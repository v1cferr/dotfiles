#!/usr/bin/env bash
# ============================================================================
#  Fixa o Linux como padrão no rEFInd (boot desatendido via Wake-on-LAN)
# ----------------------------------------------------------------------------
#  O firmware chama o rEFInd primeiro. Sem default_selection, um boot
#  desatendido (WoL) não garante o Linux. Este script seta
#  `default_selection "Linux"` no refind.conf — casa por SUBSTRING, então pega
#  qualquer entrada Linux ("Arch Linux", "Linux Boot Manager"…) e nunca casa
#  com "Windows". Após o timeout do rEFInd, ele auto-boota o Linux.
#
#  NÃO mexe em Secure Boot (é só texto de config; o binário assinado do rEFInd
#  continua o mesmo). Mantém o dualboot Arch/Windows 11 intacto — o Windows
#  segue no menu, só deixa de ser o que sobe sozinho.
#
#  Uso:  sudo ~/dotfiles/scripts/wol/boot-default-linux.sh
#        sudo ~/dotfiles/scripts/wol/boot-default-linux.sh "Arch Linux"  # exato
# ============================================================================
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Precisa de root. Rode: sudo $0" >&2
    exit 1
fi

CONF="/boot/EFI/BOOT/refind.conf"
SEL_VALUE="${1:-Linux}"
LINE="default_selection \"${SEL_VALUE}\""

[[ -f ${CONF} ]] || { echo "refind.conf não encontrado em ${CONF}" >&2; exit 1; }

# Backup uma única vez
[[ -f ${CONF}.bak ]] || { cp -a "${CONF}" "${CONF}.bak"; echo "[refind] backup: ${CONF}.bak"; }

# Substitui um default_selection ATIVO (ignora exemplos comentados '#...'),
# ou adiciona se não houver nenhum.
if grep -qE '^[[:space:]]*default_selection[[:space:]]' "${CONF}"; then
    sed -i -E "s|^[[:space:]]*default_selection[[:space:]].*|${LINE}|" "${CONF}"
else
    printf '\n# Padrão de boot desatendido (WoL): sempre Linux\n%s\n' "${LINE}" >> "${CONF}"
fi

echo "[refind] aplicado:"
grep -nE '^[[:space:]]*(default_selection|timeout)' "${CONF}" | sed 's/^/    /'
echo
echo "Verifique no PRÓXIMO boot: o rEFInd deve destacar/auto-bootar a entrada Linux."
echo "Se o rótulo da sua entrada Arch não contiver 'Linux', rode de novo passando"
echo "o nome exato, ex.:  sudo $0 \"Arch\""
