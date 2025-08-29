#!/usr/bin/env bash

# Script para relógio central com formato Tokyo Night style

# Obter informações de data e hora
current_hour=$(date '+%H')
current_date=$(date '+%a %d %b')
current_time=$(date '+%H:%M:%S')

# Função para escolher ícone baseado na hora
get_time_icon() {
    local hour=$1
    if [ "$hour" -ge 6 ] && [ "$hour" -lt 12 ]; then
        echo "🌅"  # Manhã
    elif [ "$hour" -ge 12 ] && [ "$hour" -lt 18 ]; then
        echo "☀️"   # Tarde
    elif [ "$hour" -ge 18 ] && [ "$hour" -lt 22 ]; then
        echo "🌆"  # Final de tarde
    else
        echo "🌙"  # Noite
    fi
}

# Obter ícone baseado na hora
time_icon=$(get_time_icon "$current_hour")

# Formatar saída com ícone
echo "${time_icon} ${current_date} ${current_time}"
