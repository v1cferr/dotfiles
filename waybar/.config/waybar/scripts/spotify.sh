#!/bin/bash

# Script para controlar e exibir informações do Spotify no Waybar
# Requer: playerctl

# Verifica se o playerctl está instalado
if ! command -v playerctl &> /dev/null; then
    echo '{"text": "󰎄 PlayerCtl N/A", "class": "error"}'
    exit 1
fi

# Verifica se o Spotify está em execução
if ! pgrep -x spotify > /dev/null; then
    echo '{"text": "", "class": "stopped"}'
    exit 0
fi

# Obtém o status do player
PLAYER_STATUS=$(playerctl --player=spotify status 2>/dev/null)

if [[ $? -ne 0 ]]; then
    echo '{"text": "", "class": "stopped"}'
    exit 0
fi

# Obtém metadados
ARTIST=$(playerctl --player=spotify metadata artist 2>/dev/null)
TITLE=$(playerctl --player=spotify metadata title 2>/dev/null)

# Se não conseguir obter metadados, assume que não há música
if [[ -z "$ARTIST" ]] || [[ -z "$TITLE" ]]; then
    echo '{"text": "", "class": "stopped"}'
    exit 0
fi

# Trunca strings muito longas
MAX_LENGTH=30
if [[ ${#ARTIST} -gt $MAX_LENGTH ]]; then
    ARTIST="${ARTIST:0:$MAX_LENGTH}..."
fi
if [[ ${#TITLE} -gt $MAX_LENGTH ]]; then
    TITLE="${TITLE:0:$MAX_LENGTH}..."
fi

# Formata a saída baseada no status
case "$PLAYER_STATUS" in
    "Playing")
        TEXT="$ARTIST - $TITLE"
        CLASS="playing"
        ;;
    "Paused")
        TEXT="$ARTIST - $TITLE"
        CLASS="paused"
        ;;
    *)
        TEXT=""
        CLASS="stopped"
        ;;
esac

# Cria o tooltip com informações completas
ALBUM=$(playerctl --player=spotify metadata album 2>/dev/null)
POSITION=$(playerctl --player=spotify position --format "{{ duration(position) }}" 2>/dev/null)
DURATION=$(playerctl --player=spotify metadata --format "{{ duration(mpris:length) }}" 2>/dev/null)

TOOLTIP="$ARTIST - $TITLE"
if [[ -n "$ALBUM" ]]; then
    TOOLTIP="$TOOLTIP\nÁlbum: $ALBUM"
fi
if [[ -n "$POSITION" ]] && [[ -n "$DURATION" ]]; then
    TOOLTIP="$TOOLTIP\n$POSITION / $DURATION"
fi
TOOLTIP="$TOOLTIP\nStatus: $PLAYER_STATUS"

# Saída JSON para o Waybar
printf '{"text": "%s", "class": "%s", "tooltip": "%s"}\n' "$TEXT" "$CLASS" "$TOOLTIP"
