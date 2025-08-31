#!/bin/bash

# Script completo para Waybar + SwayNC com ícones corrigidos
echo "🔄 Configurando ambiente Waybar + SwayNC..."

# Para todos os processos
echo "📍 Parando processos existentes..."
pkill waybar 2>/dev/null
pkill mako 2>/dev/null
pkill dunst 2>/dev/null
pkill swaync 2>/dev/null

# Aguarda um pouco
sleep 2

# Inicia SwayNC
echo "🔔 Iniciando SwayNC..."
swaync &
sleep 1

# Verifica se SwayNC está rodando
if pgrep swaync > /dev/null; then
    echo "✅ SwayNC iniciado com sucesso"
else
    echo "❌ Erro ao iniciar SwayNC"
fi

# Inicia Waybar
echo "🚀 Iniciando Waybar..."
cd ~/.config/waybar
waybar &
sleep 2

# Verifica se Waybar está rodando
if pgrep waybar > /dev/null; then
    echo "✅ Waybar iniciado com sucesso"
    echo ""
    echo "🎉 Sistema configurado com sucesso!"
    echo ""
    echo "📊 Funcionalidades ativas:"
    echo "  🌡️  Clima de São Carlos/SP"
    echo "  🕐  Relógio e calendário"
    echo "  🔔  Centro de notificações SwayNC"
    echo "  ♪   Integração com Spotify"
    echo "  💻  Monitoramento de CPU (com temperatura no tooltip)"
    echo "  🧠  Monitoramento de memória"
    echo "  📶  Status da rede"
    echo "  🔊  Controle de volume"
    echo ""
    echo "💡 Dicas:"
    echo "  - Clique no clima para abrir wttr.in"
    echo "  - Scroll no áudio para ajustar volume"
    echo "  - Clique nas notificações para abrir centro"
    echo "  - Controles do Spotify: click = play/pause, scroll = próxima/anterior"
else
    echo "❌ Erro ao iniciar Waybar"
    echo "🔍 Verifique os logs com: journalctl -u waybar --since '1 minute ago'"
fi

echo ""
echo "📊 Status dos processos:"
ps aux | grep -E "(waybar|swaync)" | grep -v grep
