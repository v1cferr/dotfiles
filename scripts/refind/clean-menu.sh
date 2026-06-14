#!/usr/bin/env bash
# ============================================================================
#  Deixa o menu do rEFInd com EXATAMENTE 2 entradas: Arch Linux + Windows 11
# ----------------------------------------------------------------------------
#  O rEFInd autodetecta loaders demais (kernel solto + systemd-boot = 2 Linux;
#  e bootmgfw em 2 ESPs = 2 Windows). Este script:
#    - desliga a autodetecção (scanfor manual) — só o que for manual aparece;
#    - adiciona 2 entradas MANUAIS com nome e ícone certos;
#    - fixa o Arch como padrão (boot desatendido / Wake-on-LAN).
#
#  Tudo num bloco "managed" com marcadores, idempotente. NÃO mexe em Secure
#  Boot — o Arch sobe pelo systemd-boot (assinado via sbctl) e o Windows pelo
#  bootmgfw (assinado pela MS). Os arquivos dos SOs não são tocados; só o que
#  o rEFInd MOSTRA muda.
#
#  Rollback:  sudo cp /boot/EFI/BOOT/refind.conf.bak  /boot/EFI/BOOT/refind.conf
#             (.bak = original; .prev = estado antes da última execução)
#
#  Uso:  sudo ~/dotfiles/scripts/refind/clean-menu.sh
# ============================================================================
set -euo pipefail

[[ ${EUID} -eq 0 ]] || { echo "Precisa de root. Rode: sudo $0" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
CONF="/boot/EFI/BOOT/refind.conf"
ICONS="/boot/EFI/BOOT/icons"
ESP_ARCH="645b5013-100e-4726-8145-077dfdd875d8"   # nvme1n1p1 (/boot, systemd-boot)
ESP_WIN="dd2d8e38-c28c-43fe-ada2-ddd248215d55"    # nvme0n1p1 (Windows 11 real)
BEGIN="# >>> dotfiles: menu enxuto (managed, não editar à mão) >>>"
END="# <<< dotfiles: menu enxuto (managed) <<<"

[[ -f ${CONF} ]] || { echo "refind.conf não encontrado em ${CONF}" >&2; exit 1; }

# Pré-checagem: o loader do Arch tem que existir (a ESP do Arch é a /boot)
if [[ ! -f /boot/EFI/systemd/systemd-bootx64.efi ]]; then
    echo "ERRO: /boot/EFI/systemd/systemd-bootx64.efi não existe — abortando." >&2
    exit 1
fi
[[ -f "${ICONS}/os_arch.png" ]] || { echo "ERRO: ícone os_arch.png não encontrado." >&2; exit 1; }
[[ -f "${SCRIPT_DIR}/os_win11.png" ]] || { echo "ERRO: ${SCRIPT_DIR}/os_win11.png não encontrado." >&2; exit 1; }

# Instala o ícone do Windows 11 (logo oficial, versionado no repo) na ESP
install -Dm644 "${SCRIPT_DIR}/os_win11.png" "${ICONS}/os_win11.png"

# Backups: .bak = original (nunca sobrescreve); .prev = antes desta execução
[[ -f ${CONF}.bak ]] || cp -a "${CONF}" "${CONF}.bak"
cp -a "${CONF}" "${CONF}.prev"

# Remove um bloco managed anterior (idempotência)
sed -i "/^${BEGIN}$/,/^${END}$/d" "${CONF}"

# Fixa o Arch como padrão (substitui qualquer default_selection ativo)
if grep -qE '^[[:space:]]*default_selection[[:space:]]' "${CONF}"; then
    sed -i -E 's|^[[:space:]]*default_selection[[:space:]].*|default_selection "Arch Linux"|' "${CONF}"
else
    printf '\ndefault_selection "Arch Linux"\n' >> "${CONF}"
fi

# Acrescenta o bloco managed
cat >> "${CONF}" <<EOF

${BEGIN}
# Sem autodetecção: só as 2 entradas manuais abaixo aparecem (garante
# exatamente Arch + Windows; some o kernel solto, o systemd-boot "vermelho"
# e o Windows velho do SSD SanDisk). USB/live ainda boota pela BIOS.
scanfor manual

menuentry "Arch Linux" {
    icon   /EFI/BOOT/icons/os_arch.png
    volume ${ESP_ARCH}
    loader /EFI/systemd/systemd-bootx64.efi
}

menuentry "Windows 11" {
    icon   /EFI/BOOT/icons/os_win11.png
    volume ${ESP_WIN}
    loader /EFI/Microsoft/Boot/bootmgfw.efi
}
${END}
EOF

echo "[refind] menu enxuto aplicado. default + bloco managed:"
grep -nE '^[[:space:]]*default_selection' "${CONF}" | sed 's/^/    /'
sed -n "/^${BEGIN}$/,/^${END}$/p" "${CONF}" | sed 's/^/    /'
echo
echo "[refind] backups: ${CONF}.bak (original)  ${CONF}.prev (antes desta run)"
echo "Reinicie e confira: o rEFInd deve mostrar só 'Arch Linux' e 'Windows 11'."
echo "Se algo ficar estranho:  sudo cp ${CONF}.bak ${CONF}"
