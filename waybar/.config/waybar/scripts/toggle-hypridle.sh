#!/bin/bash

# Script para alternar hypridle on/off na waybar

STATUS_FILE="/tmp/hypridle_status"

# Função para verificar se hypridle está rodando
is_running() {
    pgrep -x hypridle > /dev/null
}

# Função para obter o estado salvo
get_saved_state() {
    if [[ -f "$STATUS_FILE" ]]; then
        cat "$STATUS_FILE"
    else
        echo "enabled"
    fi
}

# Função para salvar estado
save_state() {
    echo "$1" > "$STATUS_FILE"
}

# Se chamado com argumento "toggle", alterna o estado
if [[ "$1" == "toggle" ]]; then
    if is_running; then
        # Desativa hypridle
        killall hypridle
        save_state "disabled"
        notify-send -u low -t 2000 "Hypridle" "Desativado 󰒲"
    else
        # Ativa hypridle
        hypridle &
        save_state "enabled"
        notify-send -u low -t 2000 "Hypridle" "Ativado 󰒳"
    fi
    exit 0
fi

# Retorna o status atual para a waybar
if is_running; then
    echo '{"text":"󰒳","tooltip":"Hypridle: Ativo\nClique para desativar","class":"enabled"}'
else
    echo '{"text":"󰒲","tooltip":"Hypridle: Inativo\nClique para ativar","class":"disabled"}'
fi
