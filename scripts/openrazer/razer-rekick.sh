#!/usr/bin/env bash
# ============================================================================
#  "Replug por software" do mouse Razer no boot
# ----------------------------------------------------------------------------
#  O DeathAdder V2 (1532:0084) ENUMERA normalmente no boot (LEDs acesos, tem
#  energia), mas o OpenRazer falha o handshake inicial ("Response doesn't match
#  request, command_id 0x82") e o mouse fica INERTE — sem input — até o usuário
#  replugar fisicamente. NÃO é falta de energia/VBUS (confirmado: LEDs ficam
#  acesos e re-autorizar via sysfs revive sem cortar energia).
#
#  Re-autorizar o device (authorized 0 -> 1) força um disconnect+reconnect no
#  kernel = exatamente o que o replug físico faz, e o driver/daemon re-inicializa
#  limpo. Rodado uma vez no boot, ANTES do greeter, via systemd.
#
#  Instalado em /usr/local/lib/openrazer/ pelo scripts/openrazer/deploy.sh.
# ============================================================================
set -uo pipefail

VENDOR="1532"
found=0

for idv in /sys/bus/usb/devices/*/idVendor; do
    [[ "$(cat "${idv}" 2>/dev/null)" == "${VENDOR}" ]] || continue
    dev="$(dirname "${idv}")"
    auth="${dev}/authorized"
    [[ -w "${auth}" ]] || continue
    name="$(cat "${dev}/product" 2>/dev/null || echo '?')"
    echo "[razer-rekick] re-plugando $(basename "${dev}") (${name})"
    echo 0 > "${auth}" && sleep 1 && echo 1 > "${auth}"
    found=1
done

[[ "${found}" -eq 1 ]] || echo "[razer-rekick] nenhum device Razer (${VENDOR}) encontrado"
