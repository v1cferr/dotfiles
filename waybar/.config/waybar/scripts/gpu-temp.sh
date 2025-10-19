#!/bin/bash

# Script para obter temperatura da GPU
get_gpu_temp() {
    local temp
    
    # Método 1: nvidia-smi (para GPUs NVIDIA)
    if command -v nvidia-smi >/dev/null 2>&1; then
        temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [[ -n "$temp" && "$temp" =~ ^[0-9]+$ ]]; then
            echo "${temp}°C"
            return
        fi
    fi
    
    # Método 2: radeontop ou sensors (para GPUs AMD)
    if command -v sensors >/dev/null 2>&1; then
        temp=$(sensors 2>/dev/null | grep -i "edge\|junction" | head -1 | awk '{print $2}' | sed 's/+//g' | sed 's/°C//g')
        if [[ -n "$temp" && "$temp" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            echo "${temp}°C"
            return
        fi
    fi
    
    # Método 3: hwmon para GPU
    for hwmon in /sys/class/hwmon/hwmon*/temp*_input; do
        if [[ -r "$hwmon" ]]; then
            local name_file=$(dirname "$hwmon")/name
            if [[ -r "$name_file" ]]; then
                local hwmon_name=$(cat "$name_file")
                # Procura por identificadores comuns de GPU
                if [[ "$hwmon_name" =~ (amdgpu|radeon|nouveau) ]]; then
                    temp=$(cat "$hwmon" 2>/dev/null)
                    if [[ -n "$temp" && "$temp" -gt 0 ]]; then
                        temp_c=$((temp / 1000))
                        if [[ "$temp_c" -gt 0 && "$temp_c" -lt 120 ]]; then
                            echo "${temp_c}°C"
                            return
                        fi
                    fi
                fi
            fi
        fi
    done
    
    echo "N/A"
}

get_gpu_temp
