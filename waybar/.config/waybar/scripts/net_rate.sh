#!/usr/bin/env bash

# Script para mostrar taxa de rede com ícones melhorados

iface="${1:-$(ip -o link show | awk -F': ' '/wl|wlan|wlp|enp|eth/{print $2; exit}')}"

if [ -z "$iface" ]; then
    echo "🌐 Offline"
    exit 0
fi

statefile="/tmp/waybar_net_${iface}.tmp"
rx=$(cat /sys/class/net/"$iface"/statistics/rx_bytes 2>/dev/null || echo 0)
tx=$(cat /sys/class/net/"$iface"/statistics/tx_bytes 2>/dev/null || echo 0)
now=$(date +%s)

if [ -f "$statefile" ]; then
    read prev_rx prev_tx prev_time < "$statefile"
    dt=$((now - prev_time))
    [ $dt -le 0 ] && dt=1
    rx_rate=$(( (rx - prev_rx) / dt ))
    tx_rate=$(( (tx - prev_tx) / dt ))
else
    rx_rate=0; tx_rate=0
fi

printf "%s %s %s\n" "$rx" "$tx" "$now" > "$statefile"

# Função para formatar bytes de forma legível
human() {
    local b=$1
    if [ "$b" -lt 1024 ]; then 
        echo "${b}B/s"
    elif [ "$b" -lt 1048576 ]; then 
        awk -v v="$b" 'BEGIN{printf("%.1fK/s", v/1024)}'
    elif [ "$b" -lt 1073741824 ]; then 
        awk -v v="$b" 'BEGIN{printf("%.1fM/s", v/1048576)}'
    else 
        awk -v v="$b" 'BEGIN{printf("%.1fG/s", v/1073741824)}'
    fi
}

# Ícones baseados na interface
get_interface_icon() {
    case "$iface" in
        wl*|wlan*|wlp*) echo "📶" ;;  # WiFi
        enp*|eth*)      echo "🌐" ;;  # Ethernet
        *)              echo "🔗" ;;  # Genérico
    esac
}

# Obter ícone da interface
icon=$(get_interface_icon)

# Formatar saída
rx_formatted=$(human $rx_rate)
tx_formatted=$(human $tx_rate)

echo "${icon} ⬇️${rx_formatted} ⬆️${tx_formatted}"
