# Scripts Utilitários - Tokyo Night Edition

Scripts personalizados para facilitar o gerenciamento do ambiente Hyprland com tema Tokyo Night.

## 📁 Estrutura

```text
scripts/
├── .local/bin/              # Scripts executáveis
│   ├── hypr-quick          # Ações rápidas do Hyprland
│   ├── tokyo-night         # Aplicador de tema Tokyo Night
│   └── zen-sync            # Sincroniza o tema do Zen Browser
└── README.md               # Este arquivo
```

## 🚀 Scripts Disponíveis

### 🏠 hypr-quick

Script com ações rápidas para o Hyprland.

```bash
# Ações disponíveis
hypr-quick reload          # Recarregar configuração
hypr-quick restart-bar     # Reiniciar Waybar
hypr-quick screenshot      # Screenshot com Flameshot
hypr-quick wallpaper       # Trocar wallpaper
hypr-quick wallpaper-auto  # Auto-troca ON
hypr-quick wallpaper-stop  # Auto-troca OFF
hypr-quick monitor-info    # Info dos monitores
hypr-quick workspaces      # Listar workspaces
hypr-quick kill-app        # Matar app ativo
```

### 🌃 tokyo-night

Aplicador consistente do tema Tokyo Night em várias aplicações.

```bash
# Targets disponíveis
tokyo-night gtk           # Tema GTK (Thunar, etc.)
tokyo-night rofi          # Verificar Rofi
tokyo-night waybar        # Recarregar Waybar
tokyo-night hyprland      # Recarregar Hyprland
tokyo-night zen           # Sincronizar Zen Browser
tokyo-night all           # Aplicar em tudo
tokyo-night check         # Verificar status
```

### 🌐 zen-sync

Sincroniza o tema versionado do Zen Browser com o perfil padrão ativo.

```bash
zen-sync                 # Cria/atualiza os links para userChrome.css e user.js
zen-sync check           # Mostra o perfil detectado e o estado dos links
```

## 🔧 Instalação

```bash
# Aplicar com stow
stow scripts

# Verificar se está no PATH
which hypr-quick
which tokyo-night
```

## ⚡ Uso Rápido

```bash
# Setup inicial completo
tokyo-night all

# Ações do dia a dia
hypr-quick wallpaper       # Novo wallpaper
hypr-quick screenshot      # Print da tela
hypr-quick reload          # Reload configs

# Verificar temas
tokyo-night check
```

## 🎯 Integrações

Estes scripts podem ser chamados de:

- **Keybindings** do Hyprland
- **Rofi** como aplicações
- **Terminal** diretamente
- **Waybar** com botões personalizados
- **Zen Browser** via perfil padrão detectado automaticamente

### Exemplo de Keybindings

```conf
# No hyprland.conf
bind = $mainMod SHIFT, R, exec, hypr-quick reload
bind = $mainMod SHIFT, T, exec, tokyo-night all
bind = $mainMod SHIFT, W, exec, hypr-quick wallpaper
```

## 🌈 Paleta Tokyo Night

Os scripts usam a paleta oficial:

- **Background**: #1a1b26
- **Foreground**: #c0caf5  
- **Blue**: #7aa2f7
- **Red**: #f7768e
- **Green**: #9ece6a

---

*Scripts feitos com ❤️ para manter a consistência Tokyo Night!* 🌙
