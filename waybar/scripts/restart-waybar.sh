#!/bin/bash

# Script para reiniciar o Waybar
echo "🔄 Parando Waybar..."
pkill waybar

echo "⏳ Aguardando 1 segundo..."
sleep 1

echo "🚀 Iniciando Waybar..."
cd ~/.config/waybar
waybar &

echo "✅ Waybar reiniciado!"
