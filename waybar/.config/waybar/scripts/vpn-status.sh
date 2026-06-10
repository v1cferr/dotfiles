#!/usr/bin/env bash

# Exibe status de VPN para módulo custom/vpn da Waybar.
# Prioriza conexões do NetworkManager, reconhece NetExtender e faz fallback
# para interfaces tun/wg.

set -u

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

emit_json() {
  local text="$1"
  local class="$2"
  local tooltip="$3"

  printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' \
    "$(json_escape "$text")" \
    "$(json_escape "$class")" \
    "$(json_escape "$tooltip")"
}

nm_vpns=""
if command -v nmcli >/dev/null 2>&1; then
  nm_vpns="$(nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | awk -F: '$1=="vpn" || $1=="wireguard" {print $2}')"
fi

netextender_vpn=""
if command -v netExtender >/dev/null 2>&1; then
  # netExtender exige TTY; script(1) aloca um pseudo-TTY
  netextender_status="$(script -qec "netExtender status" /dev/null 2>/dev/null || true)"
  if printf '%s' "$netextender_status" | grep -qE "Connected!!!|has been connected"; then
    netextender_vpn="FAI.UFSCAR"
  fi
fi

combined_vpns="$(printf '%s\n%s\n' "$nm_vpns" "$netextender_vpn" | sed '/^$/d')"

if [ -n "$combined_vpns" ]; then
  vpn_count="$(printf '%s\n' "$combined_vpns" | sed '/^$/d' | wc -l | tr -d ' ')"
  first_vpn="$(printf '%s\n' "$combined_vpns" | sed -n '1p')"

  if [ "$vpn_count" -gt 1 ]; then
    text="󰦝 ${first_vpn} +$((vpn_count - 1))"
  else
    text="󰦝 ${first_vpn}"
  fi

  tooltip="VPN ativa(s):\n$(printf '%s\n' "$combined_vpns")"
  emit_json "$text" "connected" "$tooltip"
  exit 0
fi

fallback_ifaces="$(ip -o link show up 2>/dev/null | awk -F': ' '{print $2}' | grep -E '^(tun[0-9]+|wg[0-9]+|ppp[0-9]+)$' || true)"
if [ -n "$fallback_ifaces" ]; then
  iface_count="$(printf '%s\n' "$fallback_ifaces" | sed '/^$/d' | wc -l | tr -d ' ')"
  first_iface="$(printf '%s\n' "$fallback_ifaces" | sed -n '1p')"

  if [ "$iface_count" -gt 1 ]; then
    text="󰦝 ${first_iface} +$((iface_count - 1))"
  else
    text="󰦝 ${first_iface}"
  fi

  tooltip="Interface(s) VPN ativa(s):\n$(printf '%s\n' "$fallback_ifaces")"
  emit_json "$text" "connected" "$tooltip"
  exit 0
fi

emit_json "󰦝" "disconnected" "VPN desconectada\nClique: painel de VPNs | Dir: menu rofi"
