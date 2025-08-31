# Rofi Configuration - Tokyo Night Theme

Esta configuração personalizada do Rofi usa o tema Tokyo Night para combinar com o resto do seu ambiente Hyprland.

## 🎨 Características

- **Tema**: Tokyo Night (cores escuras e modernas)
- **Font**: JetBrainsMono Nerd Font 12
- **Matching**: Fuzzy matching para busca inteligente
- **Icons**: Habilitados para melhor experiência visual
- **Modos disponíveis**: Apps, Run, Windows, SSH, Files

## ⌨️ Keybindings (configurados no Hyprland)

- `Super + Q`: Launcher de aplicativos (drun mode)
- `Super + R`: Executar comandos (run mode)

## 🛠️ Modos Disponíveis

1. **drun** - Launcher de aplicativos (através dos .desktop files)
2. **run** - Executar comandos do $PATH
3. **window** - Switcher de janelas
4. **ssh** - Conectar via SSH
5. **filebrowser** - Navegador de arquivos

## 🎯 Customizações

- **Transparência real** para integração com wallpaper
- **Bordas arredondadas** para design moderno
- **Cores consistentes** com o tema Tokyo Night
- **Ícones Nerd Font** para melhor aparência
- **Fuzzy search** para busca inteligente

## 📁 Estrutura

```text
~/.config/rofi/
├── config.rasi        # Configuração principal
└── tokyo-night.rasi   # Tema Tokyo Night personalizado
```

## 🔧 Instalação via Stow

Execute o stow do diretório dotfiles para aplicar as configurações:

```bash
stow rofi
```

## 🎨 Paleta de Cores Tokyo Night

- Background: #1a1b26
- Foreground: #c0caf5
- Blue: #7aa2f7
- Red: #f7768e
- Green: #9ece6a
- Yellow: #e0af68
- Purple: #bb9af7
- Cyan: #73daca
