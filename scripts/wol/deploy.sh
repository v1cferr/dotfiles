#!/usr/bin/env bash
# ============================================================================
#  Habilita Wake-on-LAN (magic packet) na placa cabeada — persistente
# ----------------------------------------------------------------------------
#  A enp4s0 é gerenciada pelo NetworkManager, então o WoL é setado NA conexão
#  do NM (802-3-ethernet.wake-on-lan = magic). O NM reaplica isso a cada vez
#  que a interface sobe, sobrevivendo a reboots. Idempotente.
#
#  PRÉ-REQUISITOS (fora do SO, feitos uma vez):
#    - BIOS do EX-B560M-V5: habilitar "Power On By PCI-E/PCI" (Wake on LAN),
#      em APM Configuration. Se a placa tiver "ErP Ready", deixe DISABLED
#      (ErP corta energia do NIC no S5 e mata o WoL).
#    - Confirmar suporte:  sudo ethtool enp4s0 | grep -i 'Supports Wake-on'
#      Tem que conter o 'g' (magic packet).
#
#  Uso:  sudo ~/dotfiles/scripts/wol/deploy.sh
# ============================================================================
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Precisa de root. Rode: sudo $0" >&2
    exit 1
fi

# Acha a conexão NM ativa do tipo ethernet (não fixa o nome "Wired connection 1")
CON="$(nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2=="802-3-ethernet"{print $1; exit}')"
if [[ -z ${CON} ]]; then
    echo "Nenhuma conexão ethernet ativa encontrada no NetworkManager." >&2
    exit 1
fi
DEV="$(nmcli -t -f GENERAL.DEVICES connection show "${CON}" | head -1 | cut -d: -f2)"
echo "[wol] conexão: ${CON}  (dev: ${DEV:-?})"

# Habilita magic packet (e limpa 'password' do SecureOn, que não usamos)
nmcli connection modify "${CON}" 802-3-ethernet.wake-on-lan magic
nmcli connection modify "${CON}" 802-3-ethernet.wake-on-lan-password "" || true

# Reaplica agora (derruba e sobe a conexão)
nmcli connection up "${CON}" >/dev/null

# Verifica no driver
if [[ -n ${DEV} ]] && command -v ethtool >/dev/null; then
    echo "[wol] estado no driver:"
    ethtool "${DEV}" | grep -iE "supports wake-on|wake-on:" | sed 's/^/    /'
    if ethtool "${DEV}" | grep -qi "Wake-on: g"; then
        echo "[wol] OK — WoL (magic packet) ativo. MAC: $(cat "/sys/class/net/${DEV}/address")"
    else
        echo "[wol] AVISO: o driver não reporta 'Wake-on: g'. Cheque a BIOS"
        echo "      (Power On By PCI-E ligado, ErP desligado) e o suporte do NIC."
    fi
fi
