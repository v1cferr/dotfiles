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

## Compartilhar a VPN com a LAN (VPN gateway)

Este desktop (`.10`) pode servir de **gateway** da VPN pra rede de casa: outros
dispositivos (ex.: a máquina do César) acessam os recursos da FAI **sem instalar
nada** — o NetExtender (x86) nem roda no roteador ARM. Só o tráfego da FAI desvia
pra cá; o resto usa a internet de casa normal. O acesso vale **só enquanto a VPN
estiver conectada** neste desktop.

Como funciona:

```
dispositivo LAN --(rota estática no roteador)--> desktop .10 --[snwl_ssltunnel]--> FAI
   (qualquer IP)     "FAI = via .10"              (NAT/masquerade)
```

- **Desktop:** o `vpn connect fai` sobe o NAT (MASQUERADE no túnel + FORWARD
  LAN↔túnel) automaticamente; o `disconnect` derruba. Regras fixas via
  `etc/sudoers.d/fai-vpn-gateway`; `ip_forward` fixado em
  `etc/sysctl.d/99-fai-vpn-gateway.conf`. Tudo aplicado pelo `deploy.sh`.
- **Roteador (OpenWrt):** rode `router/fai-vpn-gateway.sh` **no roteador** (root)
  — cria o lease fixo `.40` do `arch-cesar` e as 6 rotas dos subnets da FAI
  (`192.168.{90,100,110,130,223}.0/24` + `200.136.209.128/25`) via `.10`.

Subnets roteados pelo túnel (capturados do NetExtender conectado):
`192.168.90.0/24`, `192.168.100.0/24`, `192.168.110.0/24`, `192.168.130.0/24`,
`192.168.223.0/24`, `200.136.209.128/25` (inclui os DNS `.235`/`.247`).

> Não precisa de split-DNS: `pc.sup.fai.ufscar.br` (200.136.209.229) e
> `fai.ufscar.br` (200.136.209.236) já resolvem no DNS público pra IPs dentro do
> `/25` roteado. O nome funciona direto.

## Dependências

- `netextender` (via AUR)
  - Instale com: `yay -S netextender`
- Requer o serviço `NEService.service` rodando (o script cuida de iniciar caso não esteja).
