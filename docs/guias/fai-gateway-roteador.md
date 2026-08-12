# Gateway da VPN FAI — a metade que mora no roteador

Par manual de [`system/net/fai-gateway.nix`](../../system/net/fai-gateway.nix). Aquele
arquivo faz o PC encaminhar e mascarar; **este aqui faz alguém mandar tráfego pra ele.**
Sem os dois lados, nada acontece.

```text
celular/notebook → roteador → 192.168.1.10 → ppp0 → FAI
      (este guia)              (o .nix)
```

## Por que é manual

Duas razões independentes, e nenhuma delas é preguiça:

1. **`system/net/router.nix` recusa push de UCI de propósito** — "uma linha errada de rede
   ou firewall tranca você fora e a saída é modo failsafe com acesso FÍSICO". Aplicar por
   SSH sem commit-confirm é exatamente o que aquela decisão evita.
2. **O sudoers do roteador não tem `/etc/init.d/network`.** São NOPASSWD só `reboot`,
   `nft`, `uci`, `dnsmasq`, `firewall` e `wg-status`. Dá pra *escrever* a rota sem senha e
   não dá pra *aplicar* — o que deixaria `/etc/config/network` divergente do que roda, e o
   `router-sync diff` acusaria um drift que nem está no ar.

Ou seja: o `uci set` sai de graça, o `reload` pede sua senha. Rode você.

## Antes de começar

O lado do PC precisa estar ativo (`sudo nixos-rebuild switch --flake .`) e a VPN de pé
(`vpn connect fai`), senão não há o que testar.

## Parte 1 — rotas estáticas

⚠️ **A lista de faixas é da FAI, não nossa** — ela vem no túnel a cada conexão e pode
mudar. Não confie na lista abaixo às cegas; tire a atual do próprio túnel:

```sh
ip route show dev ppp0 | grep via | awk '{print $1}'
```

✅ **ESTA PARTE JÁ ESTÁ FEITA** (verificado 12/08/2026). As seis rotas existem como seções
NOMEADAS `fai_r1`..`fai_r6` — veja [`router/uci/network.conf`](../../router/uci/network.conf).
Elas são anteriores a este guia e ficaram anos sem efeito, porque apontavam pra um
`192.168.1.10` que não encaminhava: **a metade que faltava era a do PC**, não esta.

⚠️ Por serem nomeadas e não anônimas, `uci show network | grep '@route'` **não as mostra** —
esse grep devolve vazio e parece que não há rota nenhuma. Procure por `=route`:

```sh
sudo uci show network | grep -E '=route|fai_r'
```

Se um dia precisar recriá-las (reflash sem "keep settings"), o padrão é este — nomeadas, e
com `netmask` em vez de CIDR, como o aparelho já as tem:

```sh
i=1
for net in 192.168.90.0 192.168.100.0 192.168.110.0 192.168.130.0 192.168.223.0; do
  sudo uci set network.fai_r$i=route
  sudo uci set network.fai_r$i.interface='lan'
  sudo uci set network.fai_r$i.target="$net"
  sudo uci set network.fai_r$i.netmask='255.255.255.0'
  sudo uci set network.fai_r$i.gateway='192.168.1.10'
  i=$((i+1))
done
sudo uci set network.fai_r6=route
sudo uci set network.fai_r6.interface='lan'
sudo uci set network.fai_r6.target='200.136.209.128'
sudo uci set network.fai_r6.netmask='255.255.255.128'
sudo uci set network.fai_r6.gateway='192.168.1.10'
sudo uci commit network
sudo /etc/init.d/network reload   # ← pede senha
```

## Parte 2 — split-DNS das zonas da FAI

Sem isto você alcança a FAI **só por IP**. Os DCs `200.136.209.252` e `.247` respondem na
53 pelo túnel e resolvem os nomes internos (testado 12/08/2026).

⚠️ **A armadilha é o `rebind_protection`, que está em `1`.** O DNS da FAI devolve
`192.168.130.2` pra `fai2008.ufscar.br` — endereço RFC1918 — e o dnsmasq **descarta
respostas privadas vindas de fora** por proteção anti-rebind. Sem liberar a zona, o
split-DNS parece configurado e simplesmente não resolve, sem erro em lugar nenhum.

```sh
sudo uci add_list dhcp.@dnsmasq[0].server='/fai2008.ufscar.br/200.136.209.252'
sudo uci add_list dhcp.@dnsmasq[0].server='/fai2008.ufscar.br/200.136.209.247'
sudo uci add_list dhcp.@dnsmasq[0].rebind_domain='fai2008.ufscar.br'
sudo uci commit dhcp
sudo /etc/init.d/dnsmasq restart   # NOPASSWD; derruba o DNS da casa por ~2s
```

O `noresolv='1'` não atrapalha: entrada `server=/zona/ip` é casada por domínio mais
específico e tem precedência sobre o encaminhamento padrão pro DoH.

⚠️ **O `https-dns-proxy` é dono da lista `server`.** O init script dele usa
`uci_add_list_if_new` (aditivo, não apaga), mas tem um par
`_dnsmasq_create_server_backup` / `_dnsmasq_restore_server_backup`: no *stop* ele
restaura o backup, e se o backup foi tirado **antes** da sua entrada, ela some. Sintoma:
nomes da FAI param de resolver depois de mexer no DoH ou rebootar. Conferir com:

```sh
sudo uci show dhcp | grep fai2008
```

Se isso virar recorrente, é só re-rodar os `add_list` — são idempotentes com
`uci_add_list_if_new`.

⚠️ **NÃO use `serversfile` como plano B.** O slot é do **adblock-fast**, que o aponta pro
próprio `/var/run/adblock-fast/dnsmasq.servers` e o remove quando para (visto acontecer no
`router-sync pull` de 12/08/2026). Sobrescrevê-lo derrubaria o bloqueio de anúncios da casa
inteira, e ele te sobrescreveria de volta no próximo reload.

## Verificação

De **outro** dispositivo da rede (não do PC — ele alcança pelo túnel de qualquer jeito):

```sh
ip route get 200.136.209.229      # deve sair via 192.168.1.10
nslookup fai2008.ufscar.br        # deve devolver 192.168.130.2/.3
nc -vz 200.136.209.229 22         # deve abrir
```

Se a rota está certa e o SSH não abre, cheque no PC se a VPN caiu — com `ppp0` fora, o
tráfego morre aqui e **falha em silêncio**, sem mensagem nenhuma pro dispositivo.

## Rollback

```sh
# rotas: remova de trás pra frente (os índices deslocam)
sudo uci show network | grep '@route' | tail -1     # confira o índice antes
sudo uci delete network.@route[-1]                   # repita 6x
sudo uci commit network && sudo /etc/init.d/network reload

# dns
sudo uci del_list dhcp.@dnsmasq[0].server='/fai2008.ufscar.br/200.136.209.252'
sudo uci del_list dhcp.@dnsmasq[0].server='/fai2008.ufscar.br/200.136.209.247'
sudo uci del_list dhcp.@dnsmasq[0].rebind_domain='fai2008.ufscar.br'
sudo uci commit dhcp && sudo /etc/init.d/dnsmasq restart
```

## Depois de aplicar

```sh
router-sync pull && git -C ~/Projects/GitHub/v1cferr/dotfiles diff router/
```

Sem o `pull`, o espelho em `router/uci/` vira uma cópia que já foi verdade — que é
exatamente o que o `router-sync diff` existe pra impedir.
