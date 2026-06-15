# WireGuard — VPN de entrada na casa (OpenWrt)

VPN para **acessar a LAN de casa de fora** sem expor login nenhum à internet.
O roteador OpenWrt (Cudy WR3000, sempre ligado) é o servidor WireGuard. Uma vez
conectado, você está "dentro de casa": acorda o desktop (`wake-via-router.sh`),
faz SSH, abre serviços `*.v1cferr.dev` por IP privado, etc.

Por que WireGuard e não expor o SSH do router: a porta UDP do WireGuard é
**muda** para qualquer pacote sem a chave certa — scanners não veem nada. É o
oposto de um port-forward com prompt de login visível.

## Topologia

- Sub-rede do túnel: `10.10.10.0/24` — router `.1`, notebook `.2`, celular `.3`.
- Porta de escuta: **UDP 51820** (liberada na WAN; só isso a mais é exposto).
- **Split tunnel:** o cliente só roteia `192.168.1.0/24` (a casa) pela VPN — sua
  navegação normal não passa por casa.
- Endpoint: `ssh.v1cferr.dev:51820` (o mesmo DDNS do SSH já mantém o IP atualizado).

## Deploy

O script roda **no roteador, como root** — ele NÃO está coberto pelo stow
(roteador é outro aparelho). Ele é aditivo (preserva os forwards 80/443/2222) e
blindado: backup + dead-man switch (auto-revert em 10 min) + `fw4 check` antes
de aplicar + `reload` (não restart, preserva a sessão via conntrack).

O router roda **dropbear** (sem `su`, sem login root por chave), mas o `v1cferr`
tem `sudo` com senha. O prompt de senha precisa de um **terminal real** (não o
`!` do Claude Code, que roda sem tty):

```sh
# a partir do desktop (que alcança o router por chave):
scp -O ~/dotfiles/scripts/wireguard/deploy-router.sh v1cferr@192.168.1.1:/tmp/wg-deploy.sh
ssh -t v1cferr@192.168.1.1 'sudo sh /tmp/wg-deploy.sh'   # pede a senha do v1cferr
```

> `scp -O` força o protocolo SCP legado — o OpenWrt não inclui `sftp-server`,
> então o scp novo (baseado em SFTP) falha com "sftp-server: not found".

No fim ele imprime (e salva em `/root/wg-clients.conf`, modo 600) as configs do
notebook e do celular. **Se a sessão sobreviveu, cancele o dead-man na hora:**

```sh
ssh -t v1cferr@192.168.1.1 'sudo rm -f /tmp/wg-deadman.active'
```

Depois de copiar as configs para os dispositivos, apague o arquivo com as
chaves privadas:

```sh
ssh -t v1cferr@192.168.1.1 'sudo rm -f /root/wg-clients.conf'
```

## Clientes

- **Notebook (Linux/Win):** salve a config como `casa-wg.conf` e importe no
  WireGuard (ou `wg-quick up ./casa-wg.conf`).
- **Celular:** `qrencode -t ansiutf8 < celular.conf` e leia o QR no app WireGuard.

## Uso típico (de fora de casa)

```sh
# 1) sobe a VPN
# 2) acorda o desktop pelo router:
ssh v1cferr@192.168.1.1 sudo -n wake-desktop
# 3) quando ele subir:
ssh casa
```

## Segurança / notas

- Só a porta UDP 51820 a mais é exposta, e ela é invisível sem a chave.
- Com a VPN no ar, dá para **aposentar o port-forward 2222** e acessar o desktop
  só pelo túnel — reduz a superfície a uma única porta UDP stealth. (Opcional;
  hoje o 2222 segue ativo, já endurecido com chave-only + fail2ban.)
- Chaves privadas dos clientes nascem no router e saem só na config impressa.
  Para gerar na máquina cliente (mais seguro), troque o fluxo: gere o par no
  cliente e cole só a pública como peer no `uci`.
- Reverter tudo manualmente (no router):
  `cp /etc/config/network.wg-bak /etc/config/network && cp /etc/config/firewall.wg-bak /etc/config/firewall && /etc/init.d/network reload && /etc/init.d/firewall reload`
