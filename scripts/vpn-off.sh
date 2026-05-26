#!/usr/bin/env bash

# Desconecta as VPNs conhecidas: UFSCar (NetworkManager) e FAI (NetExtender).

set -u

UFSCAR_PROFILE="${UFSCAR_PROFILE:-VPN_UFSCar_SCL}"

if command -v nmcli >/dev/null 2>&1; then
  if nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | awk -F: '$1=="vpn" || $1=="wireguard" {print $2}' | grep -Fxq "$UFSCAR_PROFILE"; then
    echo "Desconectando $UFSCAR_PROFILE..."
    nmcli connection down id "$UFSCAR_PROFILE" || exit 1
  fi
fi

if command -v netExtender >/dev/null 2>&1; then
  netextender_status="$(netExtender status 2>/dev/null || true)"
  if printf '%s' "$netextender_status" | grep -q "Connected!!!"; then
    echo "Desconectando FAI.UFSCAR..."
    sudo netExtender disconnect
  fi
fi
