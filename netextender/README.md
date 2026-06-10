# NetExtender Dotfiles

Configurações e perfis da VPN SonicWall gerenciados via NetExtender.

A VPN SonicWall requer o uso do cliente nativo `netextender` disponível no AUR e gerencia os seus perfis globalmente em `/etc/SonicWall`.

## Perfis incluídos

- `FAI.UFSCAR` (`sslvpn` / `sonicwall`)
  - Servidor: `200.133.233.101:4433`
  - Domínio: `fai2008`
  - Usuário: `victor.ferreira`
  - Confiança de certificado armazenada

## Aplicar o perfil salvo

Como o NetExtender guarda os perfis em `/etc/SonicWall`, este pacote **não é stow** (stowar criaria um `~/etc` errado). Use o deploy idempotente:

```bash
sudo ~/dotfiles/scripts/netextender/deploy.sh
```

## Conectar

Jeito recomendado (sem prompt, usado pela Waybar e pelo painel quickshell):

```bash
vpn connect fai        # ~/.local/bin/vpn — lê FAI_VPN_PASSWORD do ~/dotfiles/.env
vpn disconnect fai
```

Pré-requisitos do fluxo sem prompt:

1. `sudo systemctl enable --now NEService` (o CLI fala com esse daemon na porta 51330)
2. `FAI_VPN_PASSWORD` preenchida no `~/dotfiles/.env` (gitignored)

Se a senha não estiver no `.env` ou a conexão automática falhar, o script abre
um terminal e cai no fluxo interativo de sempre:

```bash
~/dotfiles/scripts/fai-ufscar-vpn.sh
# ou manualmente:
sudo netExtender connect FAI.UFSCAR
```

> **Atenção:** o gateway da FAI é **SonicWall** (confirmado pelos headers HTTP).
> O perfil `FAI.UFSCAR` que existe no NetworkManager (openconnect com
> `protocol=fortinet`) **não funciona** — o openconnect não fala o protocolo do
> SonicWall. Pode ser removido com `nmcli connection delete FAI.UFSCAR`.

## Dependências

- `netextender` (via AUR)
  - Instale com: `yay -S netextender`
- Requer o serviço `NEService.service` rodando (o script cuida de iniciar caso não esteja).
