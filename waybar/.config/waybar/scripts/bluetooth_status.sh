#!/usr/bin/env bash

# Script para mostrar status do Bluetooth com ícones

if ! command -v bluetoothctl >/dev/null 2>&1; then
    echo "🚫 N/A"
    exit 0
fi

# Verificar se Bluetooth está ligado
powered=$(bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/{print $2}')

if [ "$powered" != "yes" ]; then
    echo "📶 Off"
    exit 0
fi

# Verificar dispositivos conectados
connected_devices=$(bluetoothctl devices Connected 2>/dev/null | wc -l)

if [ "$connected_devices" -gt 0 ]; then
    # Tentar obter o nome do primeiro dispositivo conectado
    first_device=$(bluetoothctl devices Connected 2>/dev/null | head -n1)
    if [ -n "$first_device" ]; then
        mac=$(echo "$first_device" | awk '{print $2}')
        name=$(bluetoothctl info "$mac" 2>/dev/null | awk -F': ' '/Name:/{print $2; exit}' | sed 's/^ *//')
        
        # Truncar nome se muito longo
        if [ ${#name} -gt 15 ]; then
            name=$(echo "$name" | cut -c1-12)...
        fi
        
        if [ "$connected_devices" -eq 1 ]; then
            echo "🔵 ${name:-Connected}"
        else
            echo "🔵 ${name:-Device} +$((connected_devices-1))"
        fi
    else
        echo "🔵 $connected_devices device(s)"
    fi
else
    echo "🔵 On"
fi
