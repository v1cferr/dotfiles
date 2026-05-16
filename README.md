# v1cferr Dotfiles - Tokyo Night

Configurações pessoais para Arch Linux com Hyprland, organizadas com GNU Stow.

Este repositório reúne meus dotfiles com foco em consistência visual (Tokyo Night), produtividade e manutenção simples.

## Visão geral

- Sistema operacional: Arch Linux
- Compositor/WM: Hyprland (Wayland)
- Tema base: Tokyo Night
- Terminal principal: Kitty
- Terminal secundário: Warp Terminal
- Shell: Zsh + Starship + Atuin
- Browser: Zen Browser
- Launcher: Rofi
- Barra: Waybar
- Notificações: SwayNC
- Screenshot: Flameshot (adapter grim)
- Gerenciamento dos dotfiles: GNU Stow

## Estrutura do repositório

```text
~/dotfiles/
├── ANOTACOES.md
├── README.md
├── README.hyprland.md
├── README.improvements.md
├── README.stow.md
├── README.waybar.md
├── cloudflare/
├── fastfetch/
├── flameshot/
├── git/
├── gtk-3.0/
├── gtk-4.0/
├── hypr/
├── kitty/
├── netextender/
├── networkmanager/
├── opencode/
├── rofi/
├── scripts/
├── starship/
├── swaync/
├── vscode/
├── wallpapers/
├── waybar/
├── zen-browser/
└── zsh/
```

## Componentes e estado atual

### Hyprland

Configuração modular em `hypr/.config/hypr/`:

- `configs/system/` para programas, ambiente, monitores e autostart
- `configs/appearance/` para visual, blur, animações e hyprpaper
- `configs/input/` para keybindings
- `configs/rules/` para regras de janela
- `scripts/` para wallpapers e utilitários

Destaques:

- Setup dual monitor:
  - `HDMI-A-1` em `1920x1080@60` (workspaces 5-8)
  - `DP-1` em `1920x1080@144` (workspaces 1-4)
- Tema Tokyo Night com transparência e blur suave
- Hyprsunset habilitado no autostart
- Hypridle habilitado no autostart
- Clipboard history via cliphist (`wl-paste --watch cliphist store`)

### Waybar

Configuração em estilo de grupos/pílulas com 3 blocos principais:

- Esquerda: workspaces + janela ativa + Spotify
- Centro: clima + relógio + notificações
- Direita: CPU, temperaturas CPU/GPU, uso GPU, RAM, disco, rede, áudio, hypridle e tray

Scripts auxiliares e módulos customizados ficam em `waybar/.config/waybar/scripts/`.

### Rofi

Tema Tokyo Night com:

- Fuzzy matching
- Ícones Nerd Font
- Modos `drun`, `run`, `window`, `ssh` e `filebrowser`

### Shell e terminal

- `zsh/.zshrc` com:
  - `zsh-syntax-highlighting`
  - `zsh-autosuggestions`
  - Atuin, Starship e Zoxide
  - aliases para Hyprland, screenshots, manutenção e MPV/YouTube
- `kitty/.config/kitty/kitty.conf` com opacidade dinâmica, Wayland nativo e tema Tokyo Night
- `starship/.config/starship.toml` com paleta Tokyo Night

### GTK

- `gtk-3.0` e `gtk-4.0` configurados para `Tokyonight-Dark`
- Fonte padrão com Nerd Font
- Cursor configurado para `Bibata-Modern-Ice` no ambiente Hyprland

### Zen Browser

Tema versionado via:

- `zen-browser/userChrome.css`
- `zen-browser/user.js`

Sincronização feita por `zen-sync`, que detecta automaticamente o perfil padrão do Zen e cria os links necessários.

### VS Code

Pacote dedicado em `vscode/` com:

- settings
- keybindings
- snippets
- lista de extensões (`extensions.txt`)

### Rede e VPN

- `networkmanager/` com perfil declarativo para `VPN_UFSCar_SCL` (openconnect/globalprotect)
- `netextender/` com perfil SonicWall `FAI.UFSCAR`
- Script de conexão para SonicWall em `scripts/fai-ufscar-vpn.sh`

### Outros módulos do repositório

- `cloudflare/`: configuração de tunnel (SSH publish)
- `fastfetch/`: configuração personalizada com blocos de hardware/software/status
- `flameshot/`: configuração Wayland com grim adapter
- `git/`: `.gitconfig` versionado
- `swaync/`: configuração do notification center
- `wallpapers/`: link para `~/Pictures/Wallpapers`
- `opencode/`: configuração MCP local/remota

## Instalação

### Pré-requisitos básicos

```bash
sudo pacman -S stow hyprland waybar rofi kitty zsh starship flameshot thunar
```

Pacotes adicionais variam conforme seus módulos (VPN, SwayNC, extensões, etc.).

### Aplicar dotfiles com Stow

```bash
git clone https://github.com/v1cferr/dotfiles.git
cd dotfiles

stow hypr rofi waybar zsh vscode gtk-3.0 gtk-4.0 flameshot wallpapers git scripts kitty starship swaync networkmanager netextender cloudflare fastfetch opencode zen-browser
```

Opcionalmente, usar:

```bash
./scripts/stow-sync.sh
```

## Comandos úteis

```bash
# Hyprland
hyprctl reload

# Scripts utilitários
hypr-quick help
tokyo-night check
zen-sync check

# Waybar
~/scripts/restart-waybar.sh

# Extensões VS Code
cat vscode/extensions.txt | xargs -L1 code --install-extension
```

## Atalhos principais (Hyprland)

Atalhos definidos em `hypr/.config/hypr/configs/input/keybindings.conf`:

- `Super + Q`: Rofi (`drun`)
- `Super + R`: Rofi (`run`)
- `Super + Return`: terminal padrão (`kitty`)
- `Super + Backspace`: terminal secundário (`warp-terminal`)
- `Super + E`: Thunar com tema GTK
- `Super + C`: fecha janela ativa
- `Super + V`: alterna floating
- `Super + 1..8`: troca workspace
- `Super + Shift + 1..8`: move janela para workspace
- `Super + Shift + S`: Flameshot GUI
- `Super + I`: troca wallpaper
- `Super + Shift + I`: inicia auto wallpaper
- `Super + Ctrl + I`: para auto wallpaper
- `Super + F9`: toggle hyprsunset

## Documentação por módulo

- `README.hyprland.md`
- `README.waybar.md`
- `README.stow.md`
- `README.improvements.md`
- `scripts/README.md`
- `vscode/README.md`
- `networkmanager/README.md`
- `netextender/README.md`
- `zen-browser/README.md`
- `wallpapers/README.md`
- `rofi/README.md`
- `waybar/README.md`

## Roadmap

Lista consolidada de melhorias em:

- `README.improvements.md`
- `ANOTACOES.md`

## Licença

MIT.
