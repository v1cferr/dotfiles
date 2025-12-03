#!/bin/bash

# Script para configurar dark mode em todo o sistema
# Este script configura GTK, Qt, dconf e outras aplicações para usar tema escuro

echo "🌙 Configurando dark mode no sistema..."

# Configurar dconf/gsettings (para apps GNOME e derivados)
if command -v gsettings &> /dev/null; then
    echo "📝 Configurando GTK via gsettings..."
    
    # GTK theme
    gsettings set org.gnome.desktop.interface gtk-theme 'Tokyonight-Dark'
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    
    # Icon theme
    gsettings set org.gnome.desktop.interface icon-theme 'Win11-dark'
    
    # Cursor theme
    gsettings set org.gnome.desktop.interface cursor-theme 'rose-pine-hyprcursor'
    gsettings set org.gnome.desktop.interface cursor-size 24
    
    echo "✅ gsettings configurado"
else
    echo "⚠️  gsettings não encontrado, pulando..."
fi

# Configurar Qt para usar dark mode
if command -v kvantummanager &> /dev/null; then
    echo "📝 Lembre-se de configurar o Kvantum Manager manualmente para usar um tema escuro"
fi

# Configurar variáveis de ambiente Qt (criar/atualizar ~/.config/qt5ct/qt5ct.conf se qt5ct estiver instalado)
if command -v qt5ct &> /dev/null; then
    mkdir -p ~/.config/qt5ct
    echo "📝 Configurando Qt5..."
    cat > ~/.config/qt5ct/qt5ct.conf << 'EOF'
[Appearance]
color_scheme_path=/usr/share/qt5ct/colors/darker.conf
custom_palette=true
icon_theme=Win11-dark
standard_dialogs=default
style=Breeze

[Fonts]
fixed=@Variant(\0\0\0@\0\0\0\x1e\0J\0\x65\0t\0\x42\0r\0\x61\0i\0n\0s\0M\0o\0n\0o@\"\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)
general=@Variant(\0\0\0@\0\0\0\x1e\0J\0\x65\0t\0\x42\0r\0\x61\0i\0n\0s\0M\0o\0n\0o@\"\0\0\0\0\0\0\xff\xff\xff\xff\x5\x1\0\x32\x10)
EOF
    echo "✅ Qt5 configurado"
fi

# Recarregar configurações GTK
if command -v xsettingsd &> /dev/null; then
    echo "📝 Reiniciando xsettingsd..."
    pkill xsettingsd 2>/dev/null
    xsettingsd &
    echo "✅ xsettingsd reiniciado"
fi

echo ""
echo "✨ Configuração concluída!"
echo ""
echo "📋 Próximos passos:"
echo "   1. Reinicie o Hyprland (Super+Shift+R ou faça logout/login)"
echo "   2. Para o Zen Browser, abra about:config e configure:"
echo "      • widget.gtk.theme-name = 'Tokyonight-Dark'"
echo "      • browser.theme.content-theme = 0 (ou 1 para forçar dark)"
echo "      • browser.theme.toolbar-theme = 0 (ou 1 para forçar dark)"
echo "   3. Para o Thunar, vá em Editar > Preferências > Exibição"
echo "      e verifique se o tema está correto"
echo ""
echo "   Ou use as extensões do navegador:"
echo "   • Dark Reader (para sites)"
echo "   • Configurações nativas do Zen Browser em Configurações > Tema"
echo ""
