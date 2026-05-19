#!/usr/bin/env bash

# Menu/toggle rapido de VPN via NetworkManager.
# Uso:
#   vpn-menu.sh menu
#   vpn-menu.sh toggle [nome-do-perfil]

set -u

DEFAULT_VPN="${DEFAULT_VPN:-VPN_UFSCar_SCL}"

notify() {
  local msg="$1"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "VPN" "$msg"
  else
    printf '%s\n' "$msg"
  fi
}

list_all_vpns() {
  nmcli -t -f TYPE,NAME connection show 2>/dev/null | awk -F: '$1=="vpn" || $1=="wireguard" {print $2}'
}

list_active_vpns() {
  nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | awk -F: '$1=="vpn" || $1=="wireguard" {print $2}'
}

is_active_vpn() {
  local name="$1"
  list_active_vpns | grep -Fxq "$name"
}

choose_launcher() {
  if command -v rofi >/dev/null 2>&1; then
    printf 'rofi\n'
    return
  fi

  if command -v wofi >/dev/null 2>&1; then
    printf 'wofi\n'
    return
  fi

  printf 'none\n'
}

show_menu() {
  local launcher
  launcher="$(choose_launcher)"

  if [ "$launcher" = "none" ]; then
    notify "Instale rofi ou wofi para usar o menu de VPN"
    exit 1
  fi

  local all_vpns active_vpns options choice
  all_vpns="$(list_all_vpns)"
  active_vpns="$(list_active_vpns)"

  if [ -z "$all_vpns" ]; then
    notify "Nenhum perfil VPN encontrado no NetworkManager"
    exit 1
  fi

  options=""

  if [ -n "$active_vpns" ]; then
    options="${options}Desconectar todas\n"
  fi

  while IFS= read -r vpn_name; do
    [ -z "$vpn_name" ] && continue
    if is_active_vpn "$vpn_name"; then
      options="${options}Desconectar: ${vpn_name}\n"
    else
      options="${options}Conectar: ${vpn_name}\n"
    fi
  done <<EOF
$all_vpns
EOF

  if [ "$launcher" = "rofi" ]; then
    choice="$(printf '%b' "$options" | rofi -dmenu -i -p "VPN")"
  else
    choice="$(printf '%b' "$options" | wofi --dmenu --prompt "VPN")"
  fi

  [ -z "$choice" ] && exit 0

  if [ "$choice" = "Desconectar todas" ]; then
    while IFS= read -r vpn_name; do
      [ -z "$vpn_name" ] && continue
      nmcli connection down id "$vpn_name" >/dev/null 2>&1 || true
    done <<EOF
$active_vpns
EOF
    notify "VPN desconectada"
    exit 0
  fi

  case "$choice" in
    Conectar:*)
      local profile
      profile="${choice#Conectar: }"
      if nmcli connection up id "$profile" >/dev/null 2>&1; then
        notify "Conectada: $profile"
      else
        notify "Falha ao conectar: $profile"
        exit 1
      fi
      ;;
    Desconectar:*)
      local profile
      profile="${choice#Desconectar: }"
      if nmcli connection down id "$profile" >/dev/null 2>&1; then
        notify "Desconectada: $profile"
      else
        notify "Falha ao desconectar: $profile"
        exit 1
      fi
      ;;
  esac
}

toggle_vpn() {
  local requested="${1:-}"
  local active_vpns target

  active_vpns="$(list_active_vpns)"
  if [ -n "$active_vpns" ]; then
    while IFS= read -r vpn_name; do
      [ -z "$vpn_name" ] && continue
      nmcli connection down id "$vpn_name" >/dev/null 2>&1 || true
    done <<EOF
$active_vpns
EOF
    notify "VPN desconectada"
    exit 0
  fi

  if [ -n "$requested" ]; then
    target="$requested"
  elif list_all_vpns | grep -Fxq "$DEFAULT_VPN"; then
    target="$DEFAULT_VPN"
  else
    target="$(list_all_vpns | sed -n '1p')"
  fi

  if [ -z "$target" ]; then
    notify "Nenhum perfil VPN disponivel"
    exit 1
  fi

  if nmcli connection up id "$target" >/dev/null 2>&1; then
    notify "Conectada: $target"
  else
    notify "Falha ao conectar: $target"
    exit 1
  fi
}

if ! command -v nmcli >/dev/null 2>&1; then
  notify "nmcli nao encontrado"
  exit 1
fi

mode="${1:-menu}"
case "$mode" in
  menu)
    show_menu
    ;;
  toggle)
    toggle_vpn "${2:-}"
    ;;
  *)
    printf 'Uso: %s [menu|toggle [perfil]]\n' "$0"
    exit 1
    ;;
esac
