# bin/

Comandos de uso diário, instalados no PATH via stow (`bin/.local/bin/` -> `~/.local/bin/`). São chamados pelo nome, de qualquer lugar.

```bash
stow bin                       # ou ./scripts/stow-sync.sh stow bin
```

Como entram no PATH, são chamados pelo nome (sem caminho) em keybindings do Hyprland, módulos do Waybar, Rofi e terminal. Mover/renomear este diretório no repo não quebra integrações que usam `~/.local/bin/<comando>`.

## Comandos

### vpn

Menu e controle das VPNs (UFSCar via NetworkManager, FAI via netExtender).

```bash
vpn                            # menu (rofi/wofi)
vpn status                     # VPNs ativas
vpn connect ufscar|fai
vpn disconnect ufscar|fai|all
vpn toggle ufscar|fai
```

### vpn-off

Desconecta todas as VPNs conhecidas (UFSCar + FAI).

### dark-mode

Aplica dark mode no sistema: GTK (gsettings), Qt (qt5ct) e recarrega o xsettingsd.

### hypr-quick

Ações rápidas do Hyprland.

```bash
hypr-quick reload | restart-bar | screenshot | wallpaper | wallpaper-auto | wallpaper-stop | monitor-info | workspaces | kill-app
```

### tokyo-night

Aplica o tema Tokyo Night nas aplicações.

```bash
tokyo-night gtk | rofi | waybar | hyprland | zen | all | check
```

### zen-sync

Sincroniza o tema versionado do Zen Browser com o perfil padrão ativo.

```bash
zen-sync                       # cria/atualiza links de userChrome.css e user.js
zen-sync check                 # mostra o perfil detectado e o estado dos links
```

## Exemplo de keybindings (Hyprland)

```conf
bind = $mainMod, N, exec, ~/.local/bin/vpn connect ufscar
bind = $mainMod SHIFT, R, exec, hypr-quick reload
bind = $mainMod SHIFT, T, exec, tokyo-night all
```
