# GTK-3 Dark Mode Configuration

Esta pasta contém as configurações do GTK-3 para ativar o modo escuro em aplicações como Thunar (file manager).

## 🌙 Configurações Aplicadas

- `gtk-application-prefer-dark-theme=1` - Força modo escuro
- `gtk-theme-name=Tokyonight-Dark` - Tema escuro Tokyonight (Night, Borderless, MacOS buttons)
- `gtk-icon-theme-name=Win11-dark` - Ícones do Windows 11 (versão escura)
- `gtk-font-name=JetBrainsMono Nerd Font` - Fonte com ícones integrados
- `gtk-cursor-theme-name=rose-pine-hyprcursor` - Cursor Rose Pine para Hyprcursor

## 🚀 Como usar

```bash
# Aplicar com stow (estando em ~/dotfiles)
stow gtk-3.0 gtk-4.0

# Configurar tema globalmente
gsettings set org.gnome.desktop.interface gtk-theme 'Tokyonight-Dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Reiniciar aplicações GTK para aplicar o tema
pkill thunar && thunar &
```

## ✅ Persistência Configurada

A configuração é persistente através de:

1. **Arquivos GTK**: `~/.config/gtk-3.0/settings.ini` e `~/.config/gtk-4.0/settings.ini`
2. **gsettings**: Tema configurado globalmente via gsettings
3. **Variável de ambiente no Zsh**: `export GTK_THEME=Tokyonight-Dark` no `.zshrc`
4. **Variável de ambiente no Hyprland**: `env = GTK_THEME,Tokyonight-Dark` no `environment.conf`

## 🎨 Tema Completo

- **Visual**: Tokyonight Dark (consistente)
- **Ícones**: Windows 11 Dark (modernos e coloridos)
- **Fonte**: JetBrains Mono Nerd Font (perfeita para desenvolvimento)
- **Cursor**: Rose Pine Hyprcursor (nativo do Hyprland)

## 💡 Troubleshooting

Se o tema não aplicar automaticamente, você pode forçar usando:

```bash
GTK_THEME=Tokyonight-Dark thunar
```

A variável `GTK_THEME` já está configurada no `.zshrc` e no `environment.conf` do Hyprland para persistência.

## 📦 Como Aplicar

```bash
# No diretório ~/dotfiles
stow gtk-3.0
```

## 🔧 Configurações Manuais Alternativas

Se preferir configurar manualmente via gsettings:

```bash
# Ativar tema escuro
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

# Verificar configurações atuais
gsettings get org.gnome.desktop.interface gtk-theme
gsettings get org.gnome.desktop.interface color-scheme
```

## 🎨 Temas Disponíveis

Temas escuros detectados no sistema:

- Tokyonight-Dark
- Adwaita-dark (padrão)

## ✅ Aplicações Afetadas

- Thunar (file manager)
- Aplicações GTK em geral
- Caixas de diálogo
- File pickers
