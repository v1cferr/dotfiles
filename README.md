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
├── RESTORE.md
├── atuin/
├── autostart/
├── bash/
├── bin/
├── btop/
├── caddy/
├── cloudflare/
├── cloudflare-ddns/
├── docker/
├── easyeffects/
├── fail2ban/
├── fastfetch/
├── flameshot/
├── fontconfig/
├── gh/
├── git/
├── gtk-3.0/
├── gtk-4.0/
├── homelab/
├── hypr/
├── kitty/
├── lazydocker/
├── mpv/
├── nano/
├── netextender/
├── networkmanager/
├── nvim/
├── opencode/
├── openrazer/
├── pacseek/
├── polychromatic/
├── rofi/
├── scripts/
├── spicetify/
├── ssh/
├── starship/
├── swap/
├── swaync/
├── system/
├── uv/
├── vlc/
├── vscode/
├── wallpapers/
├── waybar/
├── xsettingsd/
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

## Homelab e proxy reverso (Caddy)

O Caddy (serviço do sistema, via systemd) é o proxy reverso de todos os serviços self-hosted, servidos sob `*.v1cferr.dev` com certificado curinga da Let's Encrypt (desafio DNS-01 via Cloudflare). A configuração fica versionada em `caddy/`.

- Serviços expostos: Jellyfin, Jellyseerr, Prowlarr, Radarr, Sonarr, Bazarr, qBittorrent, Ollama, Open WebUI, SpendFlow e o dashboard.
- `dash.v1cferr.dev`: dashboard central (Homepage); exige basic_auth no acesso externo, aberto na LAN.
- `ai.v1cferr.dev` (Ollama): restrito à LAN (sem autenticação nativa).
- Acesso na LAN por nome via split-DNS no roteador (OpenWrt); acesso externo via port-forward 80/443.
- `fail2ban/` protege o SSH (porta 2222) e o basic_auth do dashboard.

Os stacks Docker rodam de `~/Projects/Local/` (com seus dados), mas as **configs** deles (compose + dashboard) ficam versionadas em `homelab/` como backup para reconstrução — segredos (`.env`) e dados pesados (`config/`, `database/`) ficam no `.gitignore`. Ver `homelab/README.md`.

Configurações de `/etc` não são cobertas pelo stow (que aponta para `$HOME`). Use os scripts de deploy, e mantenha os segredos em `~/dotfiles/.env` (fora do versionamento):

```bash
sudo ~/dotfiles/scripts/caddy/deploy.sh
sudo ~/dotfiles/scripts/fail2ban/deploy.sh
```

## Swap (zram + swapfile)

Swap em camadas para uso pesado de memória (16GB de RAM):

- `zram0`: RAM comprimida (zstd), `zram-size = ram` (~16G), prioridade 100 — tier rápido, usado primeiro.
- `/swapfile`: 16G no NVMe, prioridade 10 — overflow / rede de segurança contra OOM.

O kernel enche o zram primeiro e só cai pro disco quando ele lota. A configuração fica em `swap/` e é aplicada por um deploy idempotente (o stow não cobre `/etc`; o `/swapfile` é criado pelo script e a entrada do `/etc/fstab` é garantida sem reescrever o arquivo):

```bash
sudo pacman -S zram-generator          # pré-requisito (uma vez)
sudo ~/dotfiles/scripts/swap/deploy.sh
```

Detalhes em `swap/README.md`.

## DNS dinâmico (Cloudflare DDNS)

Atualizador que mantém um registro A do Cloudflare apontando para o IP público atual (usado no acesso SSH externo, `ssh.v1cferr.dev`). Roda como serviço de sistema (systemd timer). A configuração fica em `cloudflare-ddns/`; o token vive em `config/.env` (gitignored — só o `.env.example` é versionado).

```bash
cp ~/dotfiles/cloudflare-ddns/config/.env.example ~/dotfiles/cloudflare-ddns/config/.env  # preencha o token
sudo ~/dotfiles/scripts/cloudflare-ddns/deploy.sh
```

Detalhes em `cloudflare-ddns/README.md`.

## Lista de pacotes (atualização automática)

As listas de pacotes instalados (oficiais + AUR, com versão) ficam em `scripts/packages/` e são regeneradas por um timer de usuário a cada 5min — para reprodução em outra máquina e revisão de pacotes inúteis. Não faz git automático: você revisa o diff e commita quando quiser.

```bash
~/dotfiles/scripts/packages/install.sh   # ativa o timer (sem sudo)
```

Detalhes em `scripts/packages/README.md`.

## Configs de sistema (`/etc`)

Outras configs de sistema versionadas (cada uma com deploy idempotente; ver o README do pacote):

- `ssh/` — drop-in do SSH (porta 2222 + hardening). O deploy valida com `sshd -t` e faz reload (sem lockout).
- `docker/` — `daemon.json` do daemon (runtime nvidia). O deploy não reinicia o Docker.
- `system/` — `pacman.conf` + hook, `makepkg.conf` (+ drop-ins). `mkinitcpio.conf` e `boot/loader/` ficam só como **referência** (não auto-aplicados — risco de boot).
- `netextender/` — perfil de VPN SonicWall (`/etc/SonicWall/...`). Tem estrutura de `/etc`, por isso é deploy e não stow.

```bash
sudo ~/dotfiles/scripts/ssh/deploy.sh
sudo ~/dotfiles/scripts/docker/deploy.sh
sudo ~/dotfiles/scripts/system/deploy.sh
sudo ~/dotfiles/scripts/netextender/deploy.sh
```

## Disaster Recovery

Se o NVMe morrer, o **[RESTORE.md](RESTORE.md)** é o runbook passo-a-passo pra reconstruir tudo do zero: base Arch → pacotes (pacman + AUR) → `stow` dos dotfiles → deploys de `/etc` → segredos → serviços.

⚠️ O repo **não guarda segredos** (chaves SSH/GPG, `.env`, tokens — todos gitignored). Gere um backup criptografado deles com `scripts/backup-secrets.sh` e mantenha **fora do disco** (Dropbox/HDD). Sem isso, o restore não recupera SSH/GPG/tokens.

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

stow hypr rofi waybar zsh vscode gtk-3.0 gtk-4.0 flameshot wallpapers git bin kitty starship swaync networkmanager cloudflare fastfetch opencode zen-browser nvim mpv btop fontconfig spicetify easyeffects atuin autostart xsettingsd gh lazydocker uv openrazer polychromatic pacseek vlc bash nano
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
hypr-quick restart-bar

# VPN
vpn status

# Deploy de configs de sistema (/etc) - requer root
sudo ~/dotfiles/scripts/caddy/deploy.sh
sudo ~/dotfiles/scripts/fail2ban/deploy.sh
sudo ~/dotfiles/scripts/swap/deploy.sh
sudo ~/dotfiles/scripts/cloudflare-ddns/deploy.sh
sudo ~/dotfiles/scripts/ssh/deploy.sh
sudo ~/dotfiles/scripts/docker/deploy.sh
sudo ~/dotfiles/scripts/system/deploy.sh
sudo ~/dotfiles/scripts/netextender/deploy.sh

# Automação da lista de pacotes (timer de usuário, sem sudo)
~/dotfiles/scripts/packages/install.sh

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
- `bin/README.md`
- `scripts/README.md`
- `scripts/packages/README.md`
- `swap/README.md`
- `cloudflare-ddns/README.md`
- `docker/README.md`
- `homelab/README.md`
- `ssh/README.md`
- `system/README.md`
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
