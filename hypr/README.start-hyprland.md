# 🚀 Start Hyprland - Script de Inicialização

## O que é o aviso "Hyprland was started without start-hyprland..."?

Esse aviso ocorre quando o Hyprland é iniciado sem o script `start-hyprland`, que é responsável por:

- Configurar variáveis de ambiente essenciais
- Definir o tipo de sessão como Wayland
- Garantir compatibilidade com aplicações

## ✅ Solução Implementada

Script criado em: `~/.local/bin/start-hyprland`

### Variáveis configuradas

```bash
XDG_CURRENT_DESKTOP=Hyprland
XDG_SESSION_TYPE=wayland
XDG_SESSION_DESKTOP=Hyprland
MOZ_ENABLE_WAYLAND=1  # Firefox/Thunderbird no Wayland
QT_QPA_PLATFORM=wayland
SDL_VIDEODRIVER=wayland
CLUTTER_BACKEND=wayland
```

## 🎯 Como usar

### Opção 1: Terminal (TTY)

```bash
start-hyprland
# ou
~/.local/bin/start-hyprland
```

### Opção 2: Display Manager (SDDM/GDM)

Crie um arquivo `.desktop` em `/usr/share/xsessions/`:

```bash
sudo nano /usr/share/xsessions/Hyprland-custom.desktop
```

Adicione:

```ini
[Desktop Entry]
Name=Hyprland (Custom)
Comment=A dynamic tiling Wayland compositor
Exec=start-hyprland
Type=Application
```

Depois, selecione "Hyprland (Custom)" no seu login manager.

### Opção 3: Alias no zsh/bash (já está configurado)

```bash
hyprland  # Executa start-hyprland
```

## 📝 Se iniciar pelo TTY

Se estiver iniciando o Hyprland da linha de comando:

```zsh
# Simplesmente digite:
start-hyprland

# E pressione Enter
```

## 🔧 Personalização

Se precisar adicionar mais variáveis de ambiente, edite:

```bash
nano ~/.local/bin/start-hyprland
```

## ✨ Status

- ✅ Script criado e executável
- ✅ Alias adicionado ao `.zshrc`
- ✅ Variáveis de ambiente configuradas
- ✅ Pronto para uso

O aviso deve desaparecer na próxima vez que iniciar o Hyprland!
