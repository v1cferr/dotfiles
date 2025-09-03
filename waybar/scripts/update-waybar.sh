#!/bin/bash

# Script para atualizar o waybar
echo "🔄 Atualizando waybar..."

# Mata o waybar atual
killall waybar 2>/dev/null

# Aguarda um momento
sleep 1

# Inicia o waybar novamente
waybar &

echo "✅ Waybar atualizado com sucesso!"
echo "📋 Novos ícones aplicados do mechabar style"
