#!/usr/bin/env bash

# Script para mostrar uso de CPU e RAM com ícones Tokyo Night style

# Obter uso da CPU (média dos últimos 1-2 segundos)
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d',' -f1)

# Se top não funcionou, tentar com outro método
if [ -z "$cpu_usage" ]; then
    cpu_usage=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.1f", usage}')
fi

# Obter uso da RAM
ram_info=$(free | grep '^Mem:')
ram_total=$(echo "$ram_info" | awk '{print $2}')
ram_used=$(echo "$ram_info" | awk '{print $3}')
ram_percent=$(awk "BEGIN {printf \"%.0f\", $ram_used/$ram_total*100}")

# Funções para escolher ícones baseados no uso
get_cpu_icon() {
    local usage=$(echo "$1" | cut -d'.' -f1)  # Remover decimais
    if [ "$usage" -lt 30 ]; then
        echo "💤"  # Baixo
    elif [ "$usage" -lt 60 ]; then
        echo "⚡"  # Médio
    elif [ "$usage" -lt 85 ]; then
        echo "🔥"  # Alto
    else
        echo "🚨"  # Crítico
    fi
}

get_ram_icon() {
    local usage=$1
    if [ "$usage" -lt 50 ]; then
        echo "🧠"  # Normal
    elif [ "$usage" -lt 80 ]; then
        echo "📊"  # Médio
    else
        echo "⚠️"   # Alto
    fi
}

# Obter ícones
cpu_icon=$(get_cpu_icon "$cpu_usage")
ram_icon=$(get_ram_icon "$ram_percent")

# Formatar saída
echo "${cpu_icon} ${cpu_usage}% ${ram_icon} ${ram_percent}%"
