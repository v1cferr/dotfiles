# Quickshell

Painel de controle de VPN feito com [quickshell](https://quickshell.org/) (QtQuick),
integrado ao módulo `custom/vpn` da Waybar.

## O que faz

- Painel flutuante no canto superior direito (estilo Tokyo Night, igual à Waybar)
- Mostra o status das duas VPNs e conecta/desconecta com um clique:
  - `FAI.UFSCAR` — SonicWall NetExtender (senha vem do `.env` central)
  - `VPN_UFSCar_SCL` — OpenConnect via NetworkManager
- Toda a lógica fica no `~/.local/bin/vpn` (pacote `bin/`); o painel só chama
  `vpn status-json|connect|disconnect`.

## Instalação

```bash
sudo pacman -S quickshell   # pacote oficial (extra)
cd ~/dotfiles && stow quickshell
qs &                        # ou relogar (autostart no hypr/configs/system/autostart.conf)
```

## Uso

```bash
qs ipc call vpn toggle   # abre/fecha o painel (é o on-click do custom/vpn da Waybar)
qs ipc call vpn open     # "open", não "show": "show" colide com o subcomando `qs ipc show`
qs ipc call vpn hide
```

O painel lista **todas** as VPNs dinamicamente (`vpn status-json`): a FAI via
netExtender + qualquer perfil vpn/wireguard do NetworkManager.

Na Waybar (módulo `custom/vpn`, ícone 󰦝 sempre visível):

- **clique esquerdo**: painel quickshell (fallback: menu rofi se o qs não estiver rodando)
- **clique direito**: menu rofi
