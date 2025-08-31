# 🌃 v1cferr's Dotfiles - Tokyo Night Edition

> **Configurações pessoais do meu ambiente Arch Linux + Hyprland**  
> *Tokyo Night é simplesmente meu tema preferido e utilizo em tudo que consigo* 🌙

![Hyprland](https://img.shields.io/badge/Hyprland-5e81ac?style=for-the-badge&logo=wayland&logoColor=white)
![Tokyo Night](https://img.shields.io/badge/Tokyo%20Night-7aa2f7?style=for-the-badge&logo=moon&logoColor=white)
![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793d1?style=for-the-badge&logo=arch-linux&logoColor=white)
![Stow](https://img.shields.io/badge/GNU%20Stow-a3be8c?style=for-the-badge&logo=gnu&logoColor=white)

Este repositório contém todas as minhas configurações (dotfiles) para meu ambiente Linux personalizado. Tudo é baseado no **tema Tokyo Night** porque é simplesmente o melhor tema escuro que existe! 🎨

## 🚀 Visão Geral

- **OS**: Arch Linux
- **WM**: Hyprland (Wayland compositor)
- **Theme**: Tokyo Night em **TUDO** 🌃
- **Terminal**: Warp Terminal
- **Browser**: Zen Browser  
- **File Manager**: Thunar (com tema Tokyo Night)
- **Status Bar**: Waybar
- **App Launcher**: Rofi (customizado Tokyo Night)
- **Screenshot**: Flameshot
- **Gerenciamento**: GNU Stow

## 📁 Estrutura do Repositório

```text
~/dotfiles/
├── 🖥️  hypr/           # Configuração completa do Hyprland
├── 🔧  rofi/           # Launcher personalizado (Tokyo Night)
├── 📊  waybar/         # Status bar minimalista
├── 🐚  zsh/            # Shell configuration (Oh My Zsh + Agnoster)
├── 🎨  gtk-3.0/        # Tema escuro para aplicações GTK-3
├── 🎨  gtk-4.0/        # Tema escuro para aplicações GTK-4
├── 📷  flameshot/      # Configuração do screenshot tool
├── �️  wallpapers/     # Wallpapers + symlink para ~/Pictures/Wallpapers
├── 🔧  git/            # Configuração do Git com aliases úteis
├── �📜  scripts/        # Scripts utilitários personalizados
├── 📝  melhorias.md    # Lista de melhorias planejadas
└── 📖  README.md       # Este arquivo
```

## 🎨 Tema Tokyo Night - Minha Paixão

**Por que Tokyo Night?** Porque é simplesmente o tema mais elegante, moderno e confortável para os olhos que já usei!

### 🌈 Paleta de Cores Consistente

```text
Background:   #1a1b26  🌃  Escuro mas não preto total
Foreground:   #c0caf5  ✨  Texto suave e legível
Blue:         #7aa2f7  💙  Azul vibrante mas suave
Red:          #f7768e  ❤️  Vermelho elegante
Green:        #9ece6a  💚  Verde refrescante
Yellow:       #e0af68  💛  Amarelo dourado
Purple:       #bb9af7  💜  Roxo místico
Cyan:         #73daca  🩵  Ciano sereno
```

### 🎯 Aplicações com Tokyo Night

- ✅ **Hyprland**: Bordas, decorações, animações
- ✅ **Rofi**: Launcher completamente customizado
- ✅ **Waybar**: Status bar minimalista
- ✅ **GTK Apps**: Thunar, file pickers, dialogs
- ✅ **Terminal**: Theme integrado
- ✅ **Cursors**: Rose Pine Hyprcursor (combina perfeitamente)

## 🖥️ Componentes Principais

### 🏠 Hyprland Configuration

Configuração modular e super organizada:

```text
hypr/.config/hypr/
├── hyprland.conf              # Arquivo principal
├── configs/
│   ├── system/               # Sistema e programas
│   ├── appearance/           # Visual e wallpapers
│   ├── input/               # Teclado e mouse
│   └── rules/               # Regras de janelas
└── scripts/                 # Scripts de wallpaper
```

**Recursos implementados:**

- ✅ Dual monitor setup (DP-1 + HDMI-A-1)
- ✅ Workspaces por monitor (1-4 principal, 5-8 secundário)
- ✅ Sistema avançado de wallpapers
- ✅ Transparência sutil nas janelas
- ✅ Animações suaves e modernas
- ✅ Suporte completo NVIDIA + Wayland

### 🚀 Rofi - App Launcher Personalizado

Launcher completamente customizado com tema Tokyo Night:

- **Design**: Transparente com bordas arredondadas
- **Funcionalidades**: Apps, Run, Windows, SSH, Files
- **Performance**: Fuzzy search + icons
- **Keybinds**: `Super+Q` (apps), `Super+R` (run)

### 📊 Waybar - Status Bar Minimalista

Status bar clean e funcional:

- **Módulos**: Workspaces, Clock, CPU, Tray
- **Design**: Transparente com fonte Nerd
- **Integração**: Perfeitamente integrada ao Hyprland

### 🐚 Zsh - Shell Poderoso

Shell configurado com produtividade em mente:

- **Framework**: Oh My Zsh
- **Theme**: Agnoster (elegante)
- **Plugins**: Syntax highlighting, autosuggestions
- **Aliases**: Screenshots, temas GTK

### 🎨 GTK Themes - Consistência Visual

Tema escuro em todas as aplicações GTK:

- **Theme**: Tokyonight-Dark (everywhere!)
- **Icons**: Win11-dark (modernos)
- **Font**: JetBrainsMono Nerd Font
- **Cursor**: Rose Pine Hyprcursor

## ⚡ Instalação Rápida

### 📋 Pré-requisitos

```bash
# Instalar dependências principais
sudo pacman -S hyprland waybar rofi thunar flameshot
sudo pacman -S stow zsh oh-my-zsh-git
sudo pacman -S ttf-jetbrains-mono-nerd

# Para NVIDIA
sudo pacman -S nvidia-dkms nvidia-utils
```

### 🔧 Instalação

```bash
# Clone o repositório
git clone https://github.com/v1cferr/dotfiles.git
cd dotfiles

# Aplicar todas as configurações
stow hypr rofi waybar zsh gtk-3.0 gtk-4.0 flameshot wallpapers git scripts

# Reiniciar o Hyprland ou relogar
hyprctl reload
```

## ⌨️ Atalhos Principais

### 🖥️ Hyprland

| Atalho | Ação |
|--------|------|
| `Super + Q` | 🚀 Rofi Apps |
| `Super + R` | 🔧 Rofi Run |
| `Super + Return` | 💻 Terminal |
| `Super + E` | 📁 File Manager |
| `Super + C` | ❌ Fechar janela |
| `Super + V` | 🎈 Toggle floating |
| `Super + 1-9` | 🏠 Trocar workspace |
| `Super + Shift + 1-9` | 📦 Mover janela |

### 🎨 Wallpapers

| Atalho | Ação |
|--------|------|
| `Super + I` | 🎲 Wallpaper aleatório |
| `Super + Shift + I` | ⏰ Auto-troca ON |
| `Super + Ctrl + I` | ⏹️ Auto-troca OFF |

### 📷 Screenshots

| Atalho | Ação |
|--------|------|
| `Super + Shift + S` | 📸 Flameshot GUI |

## 🛠️ Scripts Personalizados

### � Hyprland Quick Actions

```bash
# Ações rápidas do Hyprland
hypr-quick reload          # Recarregar configuração
hypr-quick screenshot      # Screenshot com Flameshot
hypr-quick wallpaper       # Trocar wallpaper aleatório
hypr-quick restart-bar     # Reiniciar Waybar
```

### 🌃 Tokyo Night Theme Manager

```bash
# Gerenciador de tema Tokyo Night
tokyo-night all           # Aplicar tema em tudo
tokyo-night gtk           # Só aplicações GTK
tokyo-night check         # Verificar status dos temas
```

### �🎨 Sistema de Wallpapers

Scripts avançados para gerenciamento de wallpapers:

```bash
# Trocar wallpaper aleatório
~/.config/hypr/scripts/change_wallpapers.sh

# Auto-troca a cada 5 minutos  
~/.config/hypr/scripts/auto_wallpaper.sh

# Diagnóstico do sistema
~/.config/hypr/scripts/wallpaper_diagnostics.sh
```

## 🔤 Fontes (Em Experimentação)

Atualmente estou **testando diferentes fontes** para encontrar a perfeita:

### 🧪 Testando atualmente

- **JetBrainsMono Nerd Font** (principal no momento)
- **FiraCode Nerd Font** (considerando)
- **CascadiaCode Nerd Font** (avaliando)
- **Hack Nerd Font** (backup)

> **Nota**: A fonte ainda não está 100% definida porque estou buscando a combinação perfeita de legibilidade, ícones e estética. JetBrains está ganhando por enquanto! ✨

## 🎯 Recursos Especiais

### 🖥️ Multi-Monitor Setup

- **Monitor Principal (DP-1)**: 1920x1080@144Hz - Workspaces 1-4
- **Monitor Secundário (HDMI-A-1)**: 1920x1080@60Hz - Workspaces 5-8
- **Auto-assignment**: Workspaces fixos por monitor

### 🎨 Transparência Inteligente

- **Janelas ativas**: 97.5% opacity
- **Janelas inativas**: 87.5% opacity  
- **Background**: Transparência real no Rofi e Waybar

### ⚡ Performance NVIDIA

Configuração otimizada para placas NVIDIA + Wayland:

- G-Sync habilitado
- Hardware acceleration
- Variáveis de ambiente otimizadas

## 📝 Melhorias Planejadas

Confira o arquivo [melhorias.md](./melhorias.md) para ver o que está no roadmap!

Algumas coisas que quero implementar:

- [ ] Loading indicator no launcher
- [ ] Screen lock decente
- [ ] Clipboard history
- [ ] Blue light filter
- [ ] Finalizar decisão da fonte perfeita

## 🤝 Como Contribuir

Sinta-se à vontade para:

1. **Forks e PRs**: Melhorias são bem-vindas!
2. **Issues**: Reporte bugs ou sugira features
3. **Temas**: Adaptações para outros themes
4. **Dotfiles sharing**: Compartilhe suas configurações

## 📜 Licença

Este repositório está disponível sob licença MIT. Use, modifique e compartilhe à vontade!

## 🙏 Créditos

- **Tokyo Night Theme**: [folke/tokyonight.nvim](https://github.com/folke/tokyonight.nvim)
- **Hyprland**: [hyprwm/Hyprland](https://github.com/hyprwm/Hyprland)
- **Rose Pine Cursor**: [nana-4/rose-pine-hyprcursor](https://github.com/nana-4/rose-pine-hyprcursor)
- **JetBrains Mono**: [JetBrains/JetBrainsMono](https://github.com/JetBrains/JetBrainsMono)

---

## 💝 Feito com ❤️ e muito café ☕

*Se você gosta de Tokyo Night tanto quanto eu, deixe uma ⭐!*

[🐧 Arch Linux](https://archlinux.org) · [🌙 Tokyo Night](https://github.com/folke/tokyonight.nvim) · [🏗️ Hyprland](https://hyprland.org)
