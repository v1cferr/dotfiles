#!/usr/bin/env bash

# Abre/fecha o painel de mídia (Spotify) do quickshell, espelhando o vpn-panel.sh.
# Se o quickshell não estiver instalado/rodando, cai no play-pause direto.

set -u

for bin in qs quickshell; do
  if command -v "$bin" >/dev/null 2>&1; then
    if "$bin" ipc call mpris toggle >/dev/null 2>&1; then
      exit 0
    fi
  fi
done

exec playerctl --player=spotify play-pause
