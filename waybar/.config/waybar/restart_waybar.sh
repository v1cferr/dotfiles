#!/usr/bin/env bash

# Script para reiniciar o Waybar facilmente
echo "🔄 Reiniciando Waybar..."

# Finalizar processos do Waybar
pkill waybar

# Aguardar um pouco
sleep 1

# Iniciar o Waybar novamente
waybar &

echo "✅ Waybar reiniciado com sucesso!"
echo "📊 Configuração Tokyo Night ativa com clima de São Carlos/SP"
