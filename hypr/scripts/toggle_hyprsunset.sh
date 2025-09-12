#!/bin/bash

# Verificar se estamos em uma sessão Hyprland
if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    echo "Erro: Não está executando em uma sessão Hyprland"
    exit 1
fi

# Verificar se o socket existe
SOCKET_PATH="/run/user/$(id -u)/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
if [ ! -S "$SOCKET_PATH" ]; then
    echo "Erro: Socket do Hyprland não encontrado em $SOCKET_PATH"
    exit 1
fi

echo "Iniciando monitoramento de tela cheia para toggle do hyprsunset..."

# Função para lidar com os eventos do Hyprland
handle() {
  case $1 in
    "fullscreen>>"*)
      # Verificar o estado atual da janela ativa
      fullscreen_status=$(hyprctl activewindow -j | jq -r ".fullscreen")
      
      if [[ "$fullscreen_status" == "true" || "$fullscreen_status" == "1" ]]; then
        # Janela está em tela cheia - DESATIVAR hyprsunset
        echo "Tela cheia detectada - desativando hyprsunset"
        pkill hyprsunset 2>/dev/null
      else
        # Janela saiu da tela cheia - REATIVAR hyprsunset (apenas se não estiver rodando)
        if ! pgrep hyprsunset > /dev/null; then
          echo "Saindo da tela cheia - reativando hyprsunset"
          hyprsunset >/dev/null 2>&1 &
        fi
      fi
      ;;
  esac
}

# Conecta ao socket de eventos do Hyprland usando socat
socat -U - "UNIX-CONNECT:$SOCKET_PATH" | while read -r line; do handle "$line"; done
