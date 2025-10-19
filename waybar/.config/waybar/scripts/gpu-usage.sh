#!/bin/bash

# Script para obter uso da GPU
get_gpu_usage() {
    local usage
    
    # Método 1: nvidia-smi (para GPUs NVIDIA)
    if command -v nvidia-smi >/dev/null 2>&1; then
        usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [[ -n "$usage" && "$usage" =~ ^[0-9]+$ ]]; then
            echo "${usage}%"
            return
        fi
    fi
    
    # Método 2: radeontop (para GPUs AMD)
    if command -v radeontop >/dev/null 2>&1; then
        usage=$(timeout 1 radeontop -d - -l 1 2>/dev/null | grep -o "gpu [0-9]*" | awk '{print $2}')
        if [[ -n "$usage" && "$usage" =~ ^[0-9]+$ ]]; then
            echo "${usage}%"
            return
        fi
    fi
    
    # Método 3: /sys para AMD
    for card in /sys/class/drm/card*/device/gpu_busy_percent; do
        if [[ -r "$card" ]]; then
            usage=$(cat "$card" 2>/dev/null)
            if [[ -n "$usage" && "$usage" =~ ^[0-9]+$ ]]; then
                echo "${usage}%"
                return
            fi
        fi
    done
    
    # Método 4: intel_gpu_top (para GPUs Intel)
    if command -v intel_gpu_top >/dev/null 2>&1; then
        usage=$(timeout 1 intel_gpu_top -J 2>/dev/null | grep -o '"busy": [0-9.]*' | head -1 | awk '{print int($2)}')
        if [[ -n "$usage" && "$usage" =~ ^[0-9]+$ ]]; then
            echo "${usage}%"
            return
        fi
    fi
    
    echo "N/A"
}

get_gpu_usage
