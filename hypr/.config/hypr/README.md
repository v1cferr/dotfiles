# Hyprland Configuration

Esta é uma configuração modular e organizada do Hyprland, separada em categorias para facilitar a manutenção e customização.

## 📁 Estrutura de Pastas

```tree
~/.config/hypr/
├── hyprland.conf              # Arquivo principal (imports)
├── README.md                 # Documentação da estrutura
├── scripts/                  # 📜 Scripts utilitários
│   ├── change_wallpapers.sh  # Script para trocar wallpapers
│   ├── auto_wallpaper.sh     # Script para auto-troca de wallpapers
│   └── wallpaper_diagnostics.sh # Script de diagnóstico do sistema
└── configs/                  # 📁 Configurações modulares
    ├── system/               # 🖥️ Configurações do sistema
    │   ├── programs.conf     # Programas ($terminal, $browser, etc.)
    │   ├── environment.conf  # Variáveis de ambiente (NVIDIA, etc.)
    │   ├── monitors.conf     # Configuração dos monitores
    │   └── autostart.conf    # Programas que iniciam automaticamente
    ├── appearance/           # 🎨 Configurações visuais
    │   ├── look-and-feel.conf    # Aparência, animações, decorações
    │   ├── hyprpaper.conf        # Configuração do hyprpaper
    │   └── wallpaper-settings.conf # Configurações de wallpapers
    ├── input/               # ⌨️ Configurações de entrada
    │   ├── input.conf       # Teclado, mouse, touchpad
    │   └── keybindings.conf # Atalhos de teclado
    └── rules/               # 📋 Regras e comportamentos
        └── window-rules.conf # Regras de janelas e workspaces
```

## 🎯 Categorias

### 🖥️ System (`configs/system/`)

- **programs.conf**: Definições de programas padrão
- **environment.conf**: Variáveis de ambiente e drivers
- **monitors.conf**: Configuração de monitores e resolução
- **autostart.conf**: Aplicações que iniciam com o sistema

### 🎨 Appearance (`configs/appearance/`)

- **look-and-feel.conf**: Temas, animações, decorações, layouts
- **hyprpaper.conf**: Configuração do hyprpaper para wallpapers
- **wallpaper-settings.conf**: Configurações para scripts de wallpapers (bash only)

### ⌨️ Input (`configs/input/`)

- **input.conf**: Configurações de teclado, mouse e touchpad
- **keybindings.conf**: Todos os atalhos de teclado

### 📋 Rules (`configs/rules/`)

- **window-rules.conf**: Regras de janelas e configuração de workspaces

### 📜 Scripts (`scripts/`)

- **change_wallpapers.sh**: Script avançado para trocar wallpapers
- **auto_wallpaper.sh**: Script para auto-troca automática de wallpapers
- **wallpaper_diagnostics.sh**: Script de diagnóstico do sistema de wallpapers

## 🔧 Como Editar

Para modificar uma configuração específica:

```bash
# Editar atalhos de teclado
nano ~/.config/hypr/configs/input/keybindings.conf

# Editar aparência
nano ~/.config/hypr/configs/appearance/look-and-feel.conf

# Editar configuração de wallpapers
nano ~/.config/hypr/configs/appearance/hyprpaper.conf

# Editar programas
nano ~/.config/hypr/configs/system/programs.conf

# Recarregar configuração
hyprctl reload
```

## 🎨 Sistema de Wallpapers

O sistema de wallpapers foi completamente reformulado e agora usa o novo método `reload` do hyprpaper (mais eficiente):

### Comandos disponíveis

```bash
# Trocar wallpaper aleatório
~/.config/hypr/scripts/change_wallpapers.sh

# Trocar wallpaper específico
~/.config/hypr/scripts/change_wallpapers.sh ~/Pictures/meu_wallpaper.png

# Trocar wallpaper em monitor específico
~/.config/hypr/scripts/change_wallpapers.sh -m DP-1

# Listar wallpapers disponíveis
~/.config/hypr/scripts/change_wallpapers.sh -l

# Iniciar auto-troca (5 min)
~/.config/hypr/scripts/auto_wallpaper.sh

# Iniciar auto-troca (10 min)
~/.config/hypr/scripts/auto_wallpaper.sh -i 600

# Parar auto-troca
~/.config/hypr/scripts/auto_wallpaper.sh -s

# Diagnóstico do sistema
~/.config/hypr/scripts/wallpaper_diagnostics.sh
```

### Atalhos de teclado

- **Super + I**: Trocar wallpaper aleatório
- **Super + Shift + I**: Iniciar auto-troca de wallpapers  
- **Super + Ctrl + I**: Parar auto-troca de wallpapers

### ⚡ Melhorias técnicas

- ✅ **Método reload**: Usa `hyprctl hyprpaper reload` (mais rápido)
- ✅ **Fallback automático**: Se o reload falhar, usa método legacy
- ✅ **Evita duplicatas**: Não define o mesmo wallpaper duas vezes seguidas
- ✅ **Configuração modular**: Configurações separadas por tipo
- ✅ **Logs detalhados**: Feedback completo das operações
- ✅ **Suporte multi-monitor**: Controle individual por monitor

## 💡 Vantagens

- ✅ **Modular**: Cada categoria em sua pasta
- ✅ **Fácil manutenção**: Edite apenas o que precisa
- ✅ **Organizado**: Estrutura lógica e intuitiva
- ✅ **Compartilhável**: Compartilhe seções específicas
- ✅ **Backup seletivo**: Faça backup por categoria
- ✅ **Escalável**: Adicione novos arquivos facilmente

## 🚀 Extensões Futuras

Você pode adicionar facilmente:

- `configs/themes/` - Para diferentes temas
- `configs/workspaces/` - Para configurações específicas de workspace
- `configs/gaming/` - Para configurações de jogos
- `configs/devices/` - Para dispositivos específicos
