#!/bin/bash

echo "🔤 Configurador de Nerd Fonts para VS Code"
echo "=========================================="

# Verificar se as Nerd Fonts estão instaladas
if fc-list | grep -qi "nerd"; then
    echo "✅ Nerd Fonts encontradas no sistema"
else
    echo "❌ Nerd Fonts não encontradas. Instalando..."
    sudo pacman -S ttf-nerd-fonts-symbols-mono ttf-jetbrains-mono-nerd
fi

# Recarregar cache das fontes
echo "🔄 Recarregando cache das fontes..."
fc-cache -f -v > /dev/null 2>&1

# Verificar configuração do VS Code
VSCODE_SETTINGS="$HOME/.config/Code/User/settings.json"
if [[ -f "$VSCODE_SETTINGS" ]]; then
    if grep -q "JetBrainsMono Nerd Font" "$VSCODE_SETTINGS"; then
        echo "✅ VS Code já configurado com Nerd Fonts"
    else
        echo "⚠️  VS Code precisa ser configurado manualmente"
        echo "Adicione estas linhas ao seu settings.json:"
        echo '    "editor.fontFamily": "'\''JetBrainsMono Nerd Font'\'', '\''Fira Code'\'', monospace",'
        echo '    "terminal.integrated.fontFamily": "'\''JetBrainsMono Nerd Font Mono'\'', monospace",'
    fi
else
    echo "❌ Arquivo de configuração do VS Code não encontrado"
fi

echo ""
echo "🎨 Teste os ícones:"
echo "CPU: 󰍛 | Memória: 󰘚 | WiFi: 󰤨 | Spotify: 󰝚"
echo ""
echo "💡 Se você ainda vê quadrados ou '?', reinicie o VS Code!"
