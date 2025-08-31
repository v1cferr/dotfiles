#!/usr/bin/env bash

###########################################
### WALLPAPERS SYMLINK SCRIPT         ###
###########################################

# Script para criar symlink da pasta de wallpapers
# Facilita o versionamento e organização

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WALLPAPERS_SOURCE="$HOME/Pictures/Wallpapers"
WALLPAPERS_LINK="$DOTFILES_DIR/Pictures/Wallpapers"

echo "🎨 Configurando symlink para wallpapers..."

# Criar diretório Pictures se não existir
mkdir -p "$DOTFILES_DIR/Pictures"

# Verificar se a pasta source existe
if [ ! -d "$WALLPAPERS_SOURCE" ]; then
    echo "⚠️  Pasta $WALLPAPERS_SOURCE não existe!"
    echo "📁 Criando pasta de wallpapers..."
    mkdir -p "$WALLPAPERS_SOURCE"
fi

# Remover link existente se houver
if [ -L "$WALLPAPERS_LINK" ]; then
    echo "🔗 Removendo symlink antigo..."
    rm "$WALLPAPERS_LINK"
elif [ -d "$WALLPAPERS_LINK" ]; then
    echo "❌ Erro: $WALLPAPERS_LINK já existe como diretório!"
    echo "💡 Remova manualmente antes de continuar."
    exit 1
fi

# Criar o symlink
echo "🔗 Criando symlink: $WALLPAPERS_LINK -> $WALLPAPERS_SOURCE"
ln -s "$WALLPAPERS_SOURCE" "$WALLPAPERS_LINK"

# Verificar se funcionou
if [ -L "$WALLPAPERS_LINK" ]; then
    echo "✅ Symlink criado com sucesso!"
    echo "📊 Status do link:"
    ls -la "$WALLPAPERS_LINK"
    
    # Contar wallpapers existentes
    if [ -d "$WALLPAPERS_SOURCE" ]; then
        WALLPAPER_COUNT=$(find "$WALLPAPERS_SOURCE" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" \) 2>/dev/null | wc -l)
        echo "🖼️  Wallpapers encontrados: $WALLPAPER_COUNT"
    fi
else
    echo "❌ Erro ao criar symlink!"
    exit 1
fi

echo ""
echo "🎯 Próximos passos:"
echo "  • Execute 'stow wallpapers' para aplicar"
echo "  • Adicione wallpapers em $WALLPAPERS_SOURCE"
echo "  • Use o script de wallpapers do Hyprland normalmente"
