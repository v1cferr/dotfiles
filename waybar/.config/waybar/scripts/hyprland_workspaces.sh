#!/usr/bin/env bash
out=$(hyprctl monitors 2>/dev/null)
if [ -z "$out" ]; then
  echo "WS -"
  exit 0
fi
ws=$(printf "%s" "$out" | awk '/active workspace:/{aw=$3} /focused: yes/{print aw; exit}')
if [ -z "$ws" ]; then
  echo "WS -"
else
  echo "WS ${ws}"
fi
