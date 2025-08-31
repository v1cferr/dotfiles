#!/bin/bash

# Script para aplicar configuração de monitores e workspaces

echo "🖥️  Configurando monitores e workspaces..."

# Recarrega a configuração do Hyprland
echo "🔄 Recarregando configuração do Hyprland..."
hyprctl reload

sleep 1

# Verifica o status dos monitores
echo "📊 Status dos monitores:"
hyprctl monitors | grep -E "(Monitor|active workspace|focused)"

echo ""
echo "✅ Configuração aplicada!"
echo ""
echo "📋 Resumo da configuração:"
echo "   🖥️  Monitor Principal (DP-1): Workspaces 1-4"
echo "   🖥️  Monitor Secundário (HDMI-A-1): Workspaces 5-8"
echo ""
echo "⌨️  Novos atalhos:"
echo "   SUPER + 1-4: Vai para workspaces do monitor principal"
echo "   SUPER + 5-8: Vai para workspaces do monitor secundário"
echo "   SUPER + F1: Foca no monitor principal"
echo "   SUPER + F2: Foca no monitor secundário"
echo "   SUPER + CTRL + ←/→: Move janela entre monitores"
echo "   SUPER + TAB/SHIFT+TAB: Navega entre workspaces do mesmo monitor"
echo "   SUPER + ALT + 1,4,5,8: Vai direto para primeiro/último workspace de cada monitor"
