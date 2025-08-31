# Melhorias para fazer

## ✅ Concluído

- [X] Adicionar os Workspaces 1-4 no monitor principal
- [X] Adicionar os Workspaces 5-8 no monitor secundário
- [X] Adicionar um border-size menor e diminuir os gaps das janelas
- [X] Deixar meu file explorer em dark mode
- [X] Configurar Rofi com tema Tokyo Night personalizado
- [ ] Arrumar o clock (relógio) da [Waybar](./waybar/) para contabilizar os segundos (prefiro assim)

## 🔧 Em Progresso

- [ ] Verificar como tirar print no Hyprland com o Flameshot (isso pode ajudar: <https://www.reddit.com/r/hyprland/comments/11hr3hd/how_to_make_flameshot_work_on_hyprland/>)
- [ ] Adicionar um loading (no cursor) sempre que abrir um app com o launcher (SUPER+Q) para ter feedback do andamento

## 📋 Próximas Prioridades

### 🛡️ Must-Have Utilities (Baseado na Wiki Hyprland)

#### ⚠️ Críticos para Funcionamento

- [ ] **Notification Daemon** (URGENTE - muitos apps como Discord podem travar sem)
  - ✅ Já tenho: dunst configurado
  - Alternativas: mako, fnott, swaync
  - Starting method: Auto via D-Bus ou `exec-once` no hyprland.conf

- [ ] **Authentication Agent** (Para elevação de privilégios)
  - Considerar: hyprpolkitagent (oficial do Hyprland)
  - Starting method: manual (`exec-once`)
  - Necessário para: Instalação de software, configurações de sistema

- [ ] **XDG Desktop Portal** (Para file pickers, screensharing)
  - Instalar: xdg-desktop-portal-hyprland
  - Starting method: Automático no systemd
  - Necessário para: File pickers, screensharing, integração com apps

#### 🔊 Audio & Sistema

- [ ] **PipeWire + WirePlumber** (Para screensharing funcionar)
  - Instalar: pipewire, wireplumber (não pipewire-media-session)
  - Configurar: ~/.config/pipewire/
  - Starting method: Automático no systemd

- [ ] **Qt Wayland Support**
  - Instalar: qt5-wayland, qt6-wayland
  - Necessário para: Apps Qt funcionarem corretamente

### 🛡️ Segurança & Sistema

- [ ] **Screen Lock** (estou sem, tirando do GNOME)
  - Considerar: hyprlock (oficial), swaylock-effects
  - Integrar com: hypridle para lock automático
  
- [ ] **Idle Management**
  - Instalar: hypridle (oficial do Hyprland)
  - Configurar: ~/.config/hypr/hypridle.conf
  - Funções: Auto-lock, suspend, etc.

### 🎨 UX & Produtividade  

- [ ] **Clipboard History**
  - Considerar: cliphist (Wayland nativo), copyq
  - Integrar com: Rofi para interface
  
- [ ] **Blue Light Filter**
  - Considerar: hyprsunset (oficial), wlsunset, gammastep
  - Configurar: Automático baseado em horário

### � Melhorias em Progresso

- [ ] Verificar como tirar print no Hyprland com o Flameshot (isso pode ajudar: <https://www.reddit.com/r/hyprland/comments/11hr3hd/how_to_make_flameshot_work_on_hyprland/>)
- [ ] Adicionar um loading (no cursor) sempre que abrir um app com o launcher (SUPER+Q) para ter feedback do andamento
- [ ] Arrumar o clock (relógio) da [Waybar](./waybar/) para contabilizar os segundos (prefiro assim)

### 📦 Fontes & Dependências

- [ ] **Fonts Essenciais** (Para renderização correta)
  - Sans-serif font: noto-fonts (evita quadrados no lugar de texto)
  - Icons: Nerd Fonts ou FontAwesome (para ícones nos apps)
  - Status: Verificar se já tenho instalado

### 🔗 Dotfiles & Configurações Pendentes

#### 📁 Assets & Scripts

- [X] ~~Symlink para pasta de wallpapers~~ ✅ Implementado
- [X] ~~Scripts personalizados em ~/.local/bin/~~ ✅ Implementado

#### 🔧 Aplicações & Ferramentas

- [X] ~~Configuração do Git~~ ✅ Implementado
- [ ] Versionar ~/.ssh/config (sem chaves privadas)
- [ ] Configuração do terminal: Warp Terminal settings
- [ ] Configuração do Zen Browser (se tiver)
- [ ] Configuração do btop/htop (`~/.config/btop/`)
- [ ] Configuração do tmux (`~/.config/tmux/` ou `~/.tmux.conf`)

#### 🛠️ Development

- [ ] Configuração do Neovim (`~/.config/nvim/`)
- [ ] Configuração do VSCode (`~/.config/Code/`)
- [ ] Aliases e funções personalizadas do shell

#### 🎯 Hyprland Ecosystem Específico

- [ ] **hyprpaper** - Wallpaper daemon oficial
- [ ] **hyprpicker** - Color picker oficial  
- [ ] **hyprcursor** - Cursor management
- [ ] **hyprutils** - Utilities oficiais

## � Prioridade MÁXIMA (Implementar primeiro)

1. **Authentication Agent** - Apps podem não conseguir elevar privilégios
2. **XDG Desktop Portal** - File pickers e screensharing não funcionam sem
3. **PipeWire + WirePlumber** - Necessário para screensharing
4. **hyprlock + hypridle** - Segurança básica (screen lock)
5. **Notification Daemon** - Discord e outros apps podem travar

## �💡 Ideias Futuras

- [ ] Tema Tokyo Night para Firefox/Zen Browser
- [ ] Configurações de jogos (gamemode, etc.)
- [ ] Setup de desenvolvimento específico por linguagem
- [ ] Backup automatizado das configurações
- [ ] Script de instalação automatizada
- [ ] Configurações específicas para laptops (battery, brightness)

## 🔗 Recursos Úteis

- [Hyprland Wiki - Must Have](https://wiki.hypr.land/Useful-Utilities/Must-have/) - **Utilities essenciais**
- [Hyprland Wiki - Clipboard Managers](https://wiki.hypr.land/Useful-Utilities/Clipboard-Managers/)
- [Hyprland Ecosystem](https://wiki.hypr.land/Hypr-Ecosystem/) - Tools oficiais
- [Awesome Hyprland](https://github.com/hyprland-community/awesome-hyprland) - Lista de tools
- [Arch Wiki - Hyprland](https://wiki.archlinux.org/title/Hyprland)
- [Dotfiles inspiradores](https://github.com/topics/dotfiles)

---

**Nota**: Mantendo foco no Tokyo Night em tudo! 🌃
