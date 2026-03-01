#!/bin/bash

# Script para obter temperatura da CPU
get_cpu_temp() {
    # Tenta várias fontes de temperatura
    local temp
    
    # Método 1: sensors
    if command -v sensors >/dev/null 2>&1; then
        # Preferencia: Package id 0 (Intel), Tctl/Tdie (AMD), Core 0
        temp=$(sensors 2>/dev/null | awk '/Package id 0|Tctl|Tdie|Core 0/ {for(i=1;i<=NF;i++) if($i ~ /^\+[0-9]/) {gsub(/[+°C]/, "", $i); print $i; exit}}' | cut -d'.' -f1)
        # Se falhou, tenta temp1 como fallback final
        if [[ -z "$temp" || ! "$temp" =~ ^[0-9]+$ ]]; then
            temp=$(sensors 2>/dev/null | awk '/temp1/ {for(i=1;i<=NF;i++) if($i ~ /^\+[0-9]/) {gsub(/[+°C]/, "", $i); print $i; exit}}' | cut -d'.' -f1)
        fi
        
        if [[ -n "$temp" && "$temp" =~ ^[0-9]+$ ]]; then
            echo "${temp}°C"
            return
        fi
    fi
    
    # Método 2: hwmon direto
    for hwmon in /sys/class/hwmon/hwmon*/temp*_input; do
        if [[ -r "$hwmon" ]]; then
            temp=$(cat "$hwmon" 2>/dev/null)
            if [[ -n "$temp" && "$temp" -gt 0 ]]; then
                temp_c=$((temp / 1000))
                if [[ "$temp_c" -gt 0 && "$temp_c" -lt 120 ]]; then
                    echo "${temp_c}°C"
                    return
                fi
            fi
        fi
    done
    
    # Método 3: thermal_zone
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        if [[ -r "$zone" ]]; then
            temp=$(cat "$zone" 2>/dev/null)
            if [[ -n "$temp" && "$temp" -gt 0 ]]; then
                temp_c=$((temp / 1000))
                if [[ "$temp_c" -gt 0 && "$temp_c" -lt 120 ]]; then
                    echo "${temp_c}°C"
                    return
                fi
            fi
        fi
    done
    
    echo "N/A"
}

get_cpu_temp
