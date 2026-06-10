#!/usr/bin/env bash

# Abre/fecha o painel de VPN do quickshell. Se o quickshell nao estiver
# instalado ou rodando, cai no menu rofi de sempre (~/.local/bin/vpn menu).

set -u

for bin in qs quickshell; do
  if command -v "$bin" >/dev/null 2>&1; then
    if "$bin" ipc call vpn toggle >/dev/null 2>&1; then
      exit 0
    fi
  fi
done

exec "$HOME/.local/bin/vpn" menu
