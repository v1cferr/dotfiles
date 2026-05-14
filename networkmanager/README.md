# NetworkManager Dotfiles

Perfis de VPN do NetworkManager gerenciados via GNU Stow.

## Perfil incluído

- `VPN_UFSCar_SCL` (`openconnect` / `globalprotect`)
  - Servidor: `acessoremoto-scl.ufscar.br`
  - Protocolo: `gp`
  - Senha: **não armazenada** (será solicitada ao conectar)

**Nota:** A VPN FAI.UFSCAR (SonicWall) não é suportada nativamente pelo NetworkManager. Um script independente `fai-ufscar-vpn.sh` foi criado na pasta `scripts/` utilizando o cliente `netextender`.

## Aplicar com Stow

```bash
cd ~/dotfiles
stow networkmanager
chmod 600 ~/.config/NetworkManager/system-connections/*.nmconnection
```

## Publicar no NetworkManager (sistema)

O NetworkManager da sua maquina esta lendo perfis de VPN no escopo de sistema.
Por isso, depois do `stow`, publique os perfis declarativos em `/etc` via CLI:

```bash
cd ~/dotfiles
sudo install -d -m 700 /etc/NetworkManager/system-connections
sudo install -m 600 networkmanager/.config/NetworkManager/system-connections/*.nmconnection /etc/NetworkManager/system-connections/
sudo nmcli connection reload
```

## Recarregar e conectar

```bash
nmcli connection up FAI.UFSCAR
nmcli connection up VPN_UFSCar_SCL
```

## Dependências

- `networkmanager-vpn-plugin-openconnect` (geralmente já instalado em Arch)
  - Instale com: `sudo pacman -S networkmanager-vpn-plugin-openconnect`
