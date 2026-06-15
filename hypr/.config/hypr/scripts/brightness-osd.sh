#!/usr/bin/env bash

# Ajusta o "brilho" via gamma do hyprsunset (este desktop não tem backlight real
# — brightnessctl/ddcutil ausentes) e mostra o nível no OSD do quickshell.
# Uso: brightness-osd.sh up|down   (ligado às teclas XF86MonBrightness)

set -u

step=10
case "${1:-up}" in
  up)   hyprctl hyprsunset gamma "+$step" >/dev/null 2>&1 ;;
  down) hyprctl hyprsunset gamma "-$step" >/dev/null 2>&1 ;;
esac

# gamma resultante (o hyprsunset já clampa em [0, max-gamma])
g="$(hyprctl hyprsunset gamma 2>/dev/null | tr -dc '0-9')"
[ -z "$g" ] && g=100

# max-gamma da config (fallback 150)
conf="$HOME/.config/hypr/hyprsunset.conf"
max="$(grep -E '^[[:space:]]*max-gamma[[:space:]]*=' "$conf" 2>/dev/null | grep -oE '[0-9]+' | head -1)"
[ -z "$max" ] && max=150

# mostra no OSD (modo brilho)
qs ipc call osd brightness "$g" "$max" >/dev/null 2>&1
