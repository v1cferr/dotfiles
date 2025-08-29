#!/usr/bin/env bash

# Script para mostrar volume com ícones dinâmicos

# Obter informações de volume e mute
vol_line=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | head -n1)
mute_line=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')

if [ -z "$vol_line" ]; then
    echo "🔇 N/A"
    exit 0
fi

vol=$(echo "$vol_line" | awk '{ for(i=1;i<=NF;i++) if($i ~ /%/) {gsub("%","",$i); print $i; exit}}')

# Função para escolher ícone baseado no volume
get_volume_icon() {
    local volume=$1
    local is_muted=$2
    
    if [ "$is_muted" = "yes" ]; then
        echo "🔇"
    elif [ "$volume" -eq 0 ]; then
        echo "🔈"
    elif [ "$volume" -lt 30 ]; then
        echo "🔉"
    elif [ "$volume" -lt 70 ]; then
        echo "🔊"
    else
        echo "📢"
    fi
}

# Obter ícone apropriado
icon=$(get_volume_icon "$vol" "$mute_line")

# Formatar saída
echo "${icon} ${vol}%"
