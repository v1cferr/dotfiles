#!/usr/bin/env bash
# ============================================================================
#  Deploy da regra udev do Razer (anti-autosuspend) para o sistema
# ----------------------------------------------------------------------------
#  Problema: o DeathAdder V2 (1532:0084) NÃO expõe serial no descritor USB
#  (dmesg: "SerialNumber=0") e pede até 500mA. Com o autosuspend global do
#  kernel agressivo (usbcore.autosuspend=2 => 2s), uma porta/cabo marginal
#  desliga o device e ele não reacorda -> "sem energia, tem que replugar".
#  O mesmo race de enumeração faz o OpenRazer ler um serial TRUNCADO e criar
#  seções duplicadas no persistence.conf (o DPI "some").
#
#  Esta regra mantém power/control=on (sem autosuspend) para TODO device
#  Razer (idVendor 1532), estabilizando a enumeração e a energia.
#
#  Por que um script (e não stow): o stow-sync aponta pro $HOME e não cobre
#  /etc. O caminho é resolvido pela LOCALIZAÇÃO do script, então rodar com
#  sudo NÃO cai na pegadinha do ~ -> /root.
#
#  Uso:  sudo ~/dotfiles/scripts/openrazer/deploy.sh
# ============================================================================
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Este script precisa de root. Rode: sudo $0" >&2
    exit 1
fi

RULE_PATH="/etc/udev/rules.d/99-razer-no-autosuspend.rules"

echo ":: Instalando ${RULE_PATH}"
cat > "${RULE_PATH}" <<'EOF'
# Razer (DeathAdder V2 e cia.): desativa o USB autosuspend.
# Esses devices não expõem serial USB e pedem ~500mA; o autosuspend global
# (usbcore.autosuspend=2) os desliga e eles não reacordam -> precisa replugar.
# Mantém o device sempre energizado e estabiliza a enumeração/leitura do serial.
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1532", TEST=="power/control", ATTR{power/control}="on"
EOF

echo ":: Recarregando regras udev e re-disparando para os devices Razer"
udevadm control --reload
udevadm trigger --action=add --attr-match=idVendor=1532 || true

echo ":: Estado atual do power/control dos devices Razer:"
for p in /sys/bus/usb/devices/*/; do
    if [[ "$(cat "${p}/idVendor" 2>/dev/null)" == "1532" ]]; then
        printf '   %s -> %s\n' "$p" "$(cat "${p}/power/control" 2>/dev/null)"
    fi
done

echo ":: Pronto."
