#!/usr/bin/env bash

# Script para playerctl com ícones melhorados e informações detalhadas

status=$(playerctl status 2>/dev/null)

if [ -z "$status" ]; then
    echo "🎵 No media"
    exit 0
fi

# Obter metadados
artist=$(playerctl metadata --format '{{artist}}' 2>/dev/null)
title=$(playerctl metadata --format '{{title}}' 2>/dev/null)

# Função para escolher ícone baseado no status
get_status_icon() {
    case "$1" in
        Playing) echo "▶️" ;;
        Paused)  echo "⏸️" ;;
        Stopped) echo "⏹️" ;;
        *)       echo "🎵" ;;
    esac
}

# Montar string de metadata
meta=""
if [ -n "$artist" ] && [ -n "$title" ]; then
    meta="${artist} - ${title}"
elif [ -n "$title" ]; then
    meta="${title}"
elif [ -n "$artist" ]; then
    meta="${artist}"
else
    meta="Unknown"
fi

# Truncar se muito longo
max_length=35
if [ ${#meta} -gt $max_length ]; then
    meta="${meta:0:$((max_length-3))}..."
fi

# Obter ícone do status
icon=$(get_status_icon "$status")

# Saída final
if [ "$status" = "Playing" ]; then
    echo "${icon} ${meta}"
elif [ "$status" = "Paused" ]; then
    echo "${icon} ${meta}"
else
    echo "${icon} Stopped"
fi
