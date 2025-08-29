#!/usr/bin/env bash

# Script para mostrar temperaturas da CPU e GPU com ícones

# Função para escolher ícone baseado na temperatura
get_cpu_icon() {
    local temp=$1
    # Remover decimais e caracteres não numéricos
    temp=$(echo "$temp" | sed 's/[^0-9]//g')
    
    if [ -z "$temp" ] || [ "$temp" = "N/A" ]; then
        echo "🌡️"
    elif [ "$temp" -lt 50 ]; then
        echo "❄️"  # Frio
    elif [ "$temp" -lt 70 ]; then
        echo "🌡️"  # Normal
    elif [ "$temp" -lt 85 ]; then
        echo "🔥"  # Quente
    else
        echo "🚨"  # Muito quente
    fi
}

get_gpu_icon() {
    local temp=$1
    # Remover decimais e caracteres não numéricos
    temp=$(echo "$temp" | sed 's/[^0-9]//g')
    
    if [ -z "$temp" ] || [ "$temp" = "N/A" ]; then
        echo "🎮"
    elif [ "$temp" -lt 60 ]; then
        echo "❄️"  # Frio
    elif [ "$temp" -lt 80 ]; then
        echo "🎮"  # Normal
    elif [ "$temp" -lt 95 ]; then
        echo "🔥"  # Quente
    else
        echo "🚨"  # Muito quente
    fi
}

# Obter temperatura da CPU
cpu_temp=""
if command -v sensors >/dev/null 2>&1; then
    cpu_temp=$(sensors 2>/dev/null | awk '/Package id 0:/{print $4; exit} /Tdie:/{print $2; exit} /Core 0:/{print $3; exit}' | tr -d '+°C')
fi

if [ -z "$cpu_temp" ] && [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    cpu_temp=$(awk '{printf("%d\n",$1/1000)}' /sys/class/thermal/thermal_zone0/temp)
fi

[ -z "$cpu_temp" ] && cpu_temp="N/A"

# Obter temperatura da GPU
gpu_temp="N/A"
if command -v nvidia-smi >/dev/null 2>&1; then
    gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -n1 || echo "")
    [ -z "$gpu_temp" ] && gpu_temp="N/A"
fi

# Obter ícones baseados na temperatura
cpu_icon=$(get_cpu_icon "$cpu_temp")
gpu_icon=$(get_gpu_icon "$gpu_temp")

# Formatar saída
if [ "$gpu_temp" = "N/A" ]; then
    echo "${cpu_icon} ${cpu_temp}°C"
else
    echo "${cpu_icon} ${cpu_temp}°C ${gpu_icon} ${gpu_temp}°C"
fi
