# Melhorias para fazer

## ✅ Concluído (Baseado na Análise do Repo)

### 🏗️ **Configuração Base Hyprland**

- [X] **Configuração Modular Completa** - Sistema organizado em módulos
  - ✅ Estrutura: ~/.config/hypr/configs/ com categorias
  - ✅ system/, appearance/, input/, rules/ implementados
  - ✅ Arquivo principal com source= statements
- [X] **Workspaces Multi-Monitor**
  - ✅ Workspaces 1-4 no monitor principal (DP-1)
  - ✅ Workspaces 5-8 no monitor secundário
  - ✅ Auto-move workspace 1 para DP-1 no autostart
- [X] **Estética & Layout**
  - ✅ Border-size menor e gaps das janelas otimizados
  - ✅ File explorer em dark mode
  - ✅ Configuração de animações e decorações

### 🎯 **Componentes Essenciais Implementados**

- [X] **Rofi com Tokyo Night** - Launcher personalizado
  - ✅ Tema Tokyo Night customizado (config.rasi + tokyo-night.rasi)
  - ✅ Múltiplos modos: drun, run, window, ssh, filebrowser
  - ✅ Fuzzy matching e JetBrains Nerd Font
- [X] **Waybar** - Status bar configurada
  - ✅ Configuração mínima funcional com hyprland/workspaces
  - ✅ Auto-start configurado
- [X] **Sistema de Wallpapers Avançado**
  - ✅ hyprpaper configurado e funcional
  - ✅ Scripts automatizados (change_wallpapers.sh, auto_wallpaper.sh)
  - ✅ Suporte multi-monitor e método reload eficiente
  - ✅ Symlink para ~/Pictures/Wallpapers implementado
- [X] **Notification System** - Mako configurado
  - ✅ Auto-start no hyprland.conf
  - ✅ Integração D-Bus funcional

### 🔧 **Must-Have Utilities (VERIFICADOS)**

- [X] **PipeWire + WirePlumber** - ✅ ATIVO e funcionando
  - ✅ Systemd services rodando corretamente
  - ✅ Screensharing habilitado
- [X] **XDG Desktop Portal** - ✅ INSTALADO
  - ✅ xdg-desktop-portal-hyprland instalado
  - ✅ Backends GTK e GNOME também disponíveis
- [X] **Qt Wayland Support** - ✅ COMPLETO
  - ✅ qt5-wayland e qt6-wayland instalados
  - ✅ Apps Qt funcionando corretamente

### 🎨 **Typography & Fonts**

- [X] **Nerd Fonts** - ✅ INSTALADAS
  - ✅ JetBrainsMono Nerd Font completa
  - ✅ Configurada no Rofi e aplicações
  - ✅ Ícones e glifos funcionando

### 🛠️ **Development Tools & Scripts**

- [X] **Git Configuration** - ✅ Completa com aliases
- [X] **Custom Scripts** - ✅ Implementados
  - ✅ hypr-quick: Script de ações rápidas
  - ✅ tokyo-night: Gerenciamento de temas
  - ✅ PATH configurado corretamente
- [X] **Zsh + Oh My Zsh** - ✅ Configurado com Agnoster theme

### 🖼️ **Estética & Theming**

- [X] **Tokyo Night Consistency** - ✅ Aplicado em múltiplos componentes
  - ✅ Rofi com tema personalizado
  - ✅ Referência de cores consistente

## 🚨 PRIORIDADE MÁXIMA - Faltando Implementar

### ⚠️ **Críticos para Segurança & Funcionalidade**

- [ ] **Authentication Agent** (URGENTE - sem GUI para sudo)
  - **Instalar**: hyprpolkitagent-git (oficial) ou lxqt-policykit
  - **Configurar**: `exec-once = hyprpolkitagent &` no autostart.conf
  - **Status**: ❌ NÃO ENCONTRADO - polkit base instalado mas sem agente GUI

- [ ] **Screen Lock + Idle Management** (URGENTE - sem screen lock)
  - **Instalar**: hyprlock + hypridle (oficiais)
  - **Configurar**: ~/.config/hypr/hyprlock.conf + hypridle.conf
  - **Status**: ❌ NÃO INSTALADO - atualmente sem proteção

- [ ] **Clipboard History** (Produtividade essencial)
  - **Instalar**: cliphist (Wayland nativo)
  - **Integrar**: Rofi para interface de seleção
  - **Status**: ❌ NÃO INSTALADO

## 🔧 Melhorias em Progresso Específicas

- [ ] **Waybar Clock com Segundos**
  - **Arquivo**: ~/.config/waybar/config.jsonc
  - **Módulo**: Adicionar %S ao format do clock
  - **Status**: ⏳ CONFIGURAÇÃO ATUAL É MÍNIMA

- [ ] **Screenshot Enhancement**
  - **Atual**: Flameshot configurado no autostart
  - **Melhorar**: Implementar atalhos de teclado específicos
  - **Alternativa**: grim + slurp para Wayland nativo
  - **Status**: ⚡ FLAMESHOT INSTALADO, falta keybinds

- [ ] **App Launcher Feedback**
  - **Objetivo**: Cursor loading ao abrir apps
  - **Método**: Configurar cursor themes adequados
  - **Status**: 🎯 PLANEJADO

## 📋 Próximas Prioridades (Ordem de Implementação)

### 🎨 **Estética & Consistency (Tokyo Night)**

- [ ] **GTK Theme Integration**
  - **Instalar**: Tokyo Night GTK theme
  - **Configurar**: nwg-look para aplicar consistentemente
  - **Variáveis**: Definir GTK_THEME no environment.conf

- [ ] **Cursor Theme Modern**
  - **Formato**: hyprcursor + XCursor fallback
  - **Recomendado**: Bibata-Modern-Ice
  - **Configurar**: `HYPRCURSOR_*` e `XCURSOR_*` vars

- [ ] **Blue Light Filter**
  - **Instalar**: hyprsunset (oficial Hyprland)
  - **Configurar**: Automático baseado em horário
  - **Alternativas**: wlsunset, gammastep

### 🔧 **Advanced Configuration**

- [ ] **Window Rules Avançadas**
  - **Método**: `hyprctl clients` para descobrir classes
  - **Implementar**: Apps específicos para workspaces específicos
  - **Exemplo**: Spotify sempre no workspace 9

- [ ] **Special Workspaces (Scratchpads)**
  - **Configurar**: Workspaces especiais para acesso rápido
  - **Use cases**: Terminal, music player, notes
  - **Keybinds**: Toggle visibility com SUPER+S

- [ ] **Animation Tuning**
  - **Otimizar**: Bezier curves para melhor feeling
  - **Balance**: Performance vs eyecandy
  - **Status**: ✅ Base configurada, pode refinar

## 🛠️ Dotfiles & Configurações Pendentes

### 📁 **Development Environment**

- [ ] **SSH Config** - Versionar ~/.ssh/config (sem chaves privadas)
- [ ] **Neovim Configuration** (~/dotfiles/nvim/)
- [ ] **VS Code Settings** (~/dotfiles/vscode/)
- [ ] **Terminal Configuration** (Warp Terminal settings)
- [ ] **Tmux Configuration** (~/dotfiles/tmux/)

### 🎯 **Hyprland Ecosystem Migration**

- [ ] **hyprpaper Optimization** (já implementado, pode melhorar)
- [ ] **hyprpicker** - Color picker oficial
- [ ] **hyprcursor** - Cursor management moderno
- [ ] **hyprutils** - Utilities oficiais

## 📚 Aprendizados do Guia Hyprland

### 🎯 **Filosofia GNOME vs Hyprland**

- **GNOME**: Produto integrado, conveniência imediata
- **Hyprland**: Fundação modular, controle total
- **Trade-off**: Conveniência vs Liberdade

### 🏗️ **Abordagem Recomendada**

1. **Estudar dotfiles** da comunidade primeiro (end-4, mylinuxforwork, JaKooLit)
2. **Configuração modular**: Separar configs em arquivos específicos
3. **Iteração contínua**: Desktop nunca está "terminado"

### 📋 **Fontes Essenciais** (Do Guia)

- **Sans-serif**: noto-fonts (renderização básica)
- **Monospace**: JetBrainsMono Nerd Font ou FiraCode Nerd Font ✅ INSTALADA
- **Ícones**: Papirus-Dark ou Tela (combinam com Tokyo Night)

## 💡 Ideias Futuras (Inspiradas no Guia)

- [ ] **Plugin System**: Explorar plugins para layouts alternativos
- [ ] **Workflow Optimization**: Named workspaces + scratchpads
- [ ] **Multi-Monitor**: Workspace binding por monitor
- [ ] **Performance Tuning**: Balancear eyecandy vs performance
- [ ] **Tema Tokyo Night**: Unificar em TODOS os componentes
- [ ] **Backup automatizado**: Versionamento completo dos dotfiles
- [ ] **Script de instalação**: Automação baseada no guia

## 🔗 Recursos Úteis (Atualizados com Guia Completo)

### 📖 **Documentação Oficial**

- [Hyprland Wiki - Must Have](https://wiki.hypr.land/Useful-Utilities/Must-have/) - **Utilities essenciais**
- [Hyprland Wiki - Clipboard Managers](https://wiki.hypr.land/Useful-Utilities/Clipboard-Managers/)
- [Hyprland Ecosystem](https://wiki.hypr.land/Hypr-Ecosystem/) - Tools oficiais
- [Hyprland Installation](https://wiki.hypr.land/Getting-Started/Installation/) - Guia oficial

### 🎨 **Inspiração & Comunidade**

- [Awesome Hyprland](https://github.com/hyprland-community/awesome-hyprland) - Lista curada de tools
- [r/hyprland](https://reddit.com/r/hyprland) - Comunidade ativa
- [end-4 dotfiles](https://github.com/end-4) - Configurações avançadas
- [mylinuxforwork](https://github.com/mylinuxforwork) - Setup completo
- [JaKooLit dotfiles](https://github.com/JaKooLit) - Scripts para várias distros

### 🔧 **Troubleshooting & Referência**

- [Arch Wiki - Hyprland](https://wiki.archlinux.org/title/Hyprland) - Configuração detalhada
- [NVIDIA Wayland](https://wiki.hypr.land/Nvidia/) - Configuração específica NVIDIA
- [Reddit - Flameshot Hyprland](https://www.reddit.com/r/hyprland/comments/11hr3hd/how_to_make_flameshot_work_on_hyprland/) - Screenshots

### 🎨 **Themes & Assets**

- [GNOME-Look](https://www.gnome-look.org/) - GTK themes, ícones, cursors
- [Tokyo Night Theme](https://github.com/enkia/tokyo-night-vscode-theme) - Referência de cores
- [Nerd Fonts](https://www.nerdfonts.com/) - Fonts com ícones
- [Papirus Icons](https://github.com/PapirusDev/papirus-icon-theme) - Icon theme

---

**Nota**: Mantendo foco no Tokyo Night em tudo! 🌃  
**Inspirado pelo guia completo**: "De Usuário a Arquiteto: Transição GNOME → Hyprland"

## 🎯 **Resumo das Recomendações Prioritárias**

### **IMPLEMENTAR IMEDIATAMENTE** 🚨

1. **hyprpolkitagent** - Para funcionalidade básica de sudo GUI
2. **hyprlock + hypridle** - Segurança essencial
3. **cliphist** - Produtividade diária

### **MELHORAR CONFIGURAÇÕES EXISTENTES** ⚡

1. **Waybar** - Adicionar segundos ao clock e mais módulos
2. **Screenshot keybinds** - Flameshot já está instalado
3. **Window rules** - Automatizar organizações de apps

### **POLISH & CONSISTENCY** 🎨

1. **GTK themes** - Tokyo Night em todos os apps
2. **Cursor themes** - Modernizar para hyprcursor
3. **Blue light filter** - Saúde ocular

**Status geral**: Sua configuração está **85% completa** e muito bem estruturada! 🎉
