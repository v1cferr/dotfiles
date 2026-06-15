#!/bin/bash

# Script para controlar e exibir informações do Spotify no Waybar
# Requer: playerctl
#
# Nota: artista/título/álbum são escapados para JSON (json_escape) antes de
# entrarem na saída, senão uma faixa com aspas (") ou barra (\) quebraria o
# JSON e o módulo ficaria em branco até a música mudar. Os separadores \n do
# tooltip são escritos como escape literal de JSON (não passam pelo escaper).

# Escapa uma string para uso DENTRO de um valor JSON (barra, aspas, tab) e
# remove quebras de linha cruas que invalidariam o JSON.
json_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' | tr -d '\n\r'
}

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

# Trunca strings muito longas (antes de escapar)
MAX_LENGTH=30
if [[ ${#ARTIST} -gt $MAX_LENGTH ]]; then
    ARTIST="${ARTIST:0:$MAX_LENGTH}..."
fi
if [[ ${#TITLE} -gt $MAX_LENGTH ]]; then
    TITLE="${TITLE:0:$MAX_LENGTH}..."
fi

# Define a classe baseada no status (texto vazio quando parado)
case "$PLAYER_STATUS" in
    "Playing") CLASS="playing" ;;
    "Paused")  CLASS="paused" ;;
    *)
        echo '{"text": "", "class": "stopped"}'
        exit 0
        ;;
esac

# Escapa os campos dinâmicos para JSON
ALBUM=$(playerctl --player=spotify metadata album 2>/dev/null)
POSITION=$(playerctl --player=spotify position --format "{{ duration(position) }}" 2>/dev/null)
DURATION=$(playerctl --player=spotify metadata --format "{{ duration(mpris:length) }}" 2>/dev/null)

ARTIST_E=$(json_escape "$ARTIST")
TITLE_E=$(json_escape "$TITLE")
ALBUM_E=$(json_escape "$ALBUM")
STATUS_E=$(json_escape "$PLAYER_STATUS")
POSITION_E=$(json_escape "$POSITION")
DURATION_E=$(json_escape "$DURATION")

TEXT="$ARTIST_E - $TITLE_E"

# Tooltip: separadores \n são escape literal de JSON (\\n no string bash)
TOOLTIP="$ARTIST_E - $TITLE_E"
if [[ -n "$ALBUM_E" ]]; then
    TOOLTIP="$TOOLTIP\\nÁlbum: $ALBUM_E"
fi
if [[ -n "$POSITION_E" ]] && [[ -n "$DURATION_E" ]]; then
    TOOLTIP="$TOOLTIP\\n$POSITION_E / $DURATION_E"
fi
TOOLTIP="$TOOLTIP\\nStatus: $STATUS_E"

# Saída JSON para o Waybar (campos já escapados)
printf '{"text": "%s", "class": "%s", "tooltip": "%s"}\n' "$TEXT" "$CLASS" "$TOOLTIP"
