# ═══════════════════════════════════════════════════════════════════════════
# Tor — SÓ CLIENTE: um SOCKS5 em 127.0.0.1:9050 pra dar saída anônima a CLI que
# aceita proxy (o consumidor de hoje é o `mega-tor`, home/net/mega.nix).
#
# POR QUE aqui e não no home/: é daemon de sistema com usuário próprio e estado em
# /var/lib/tor (regra 4). Fica no painel de serviços porque é uso pontual — desligar
# não quebra nada além dos CLIs que apontam pro 9050.
#
# NUNCA relay/exit (ClientOnly): relay entrega banda e, no caso do exit, o tráfego de
# terceiros sai com MEU IP. Aqui só se CONSOME a rede.
#
# PEGADINHAS (as três primeiras contrariam o que o wiki do NixOS mostra):
#   1. `enable` sozinho sobe o daemon SEM porta de saída — quem abre o SOCKS é
#      `client.enable`. Sem ele o serviço fica "active" e nada consegue usar.
#   2. `openFirewall = true` do exemplo do wiki é pra RELAY. O listener aqui é
#      127.0.0.1, não há o que abrir — e abrir viraria proxy aberto pra LAN.
#   3. A "segunda porta rápida 9063" do wiki NÃO EXISTE neste nixpkgs: o módulo gera UMA
#      SOCKSPort a partir de `client.socksListenAddress` (9050 + IsolateDestAddr). O 9063
#      é só o default do wrapper `torsocks-faster` (services.tor.torsocks) — habilitar o
#      torsocks instalaria um wrapper apontando pra porta onde ninguém escuta. Por isso o
#      torsocks fica FORA: o consumidor daqui fala SOCKS nativamente. Se um dia entrar um
#      programa sem suporte a proxy (wget, p.ex.), aí sim torsocks — e nesse commit tem que
#      vir junto uma SOCKSPort 9063 declarada à mão, senão o `-faster` é armadilha.
#   4. SafeSocks recusa SOCKS4 e SOCKS5-com-IP, ou seja: quem resolve DNS localmente e
#      manda o IP pronto toma ERRO em vez de vazar a consulta. O preço é que todo
#      consumidor precisa usar `socks5h://` (h = hostname resolvido pelo Tor).
#   5. BANDA: um circuito são 3 saltos voluntários — na prática centenas de KB/s. O
#      próprio projeto Tor desencoraja granel (a rede é dimensionada pra latência baixa,
#      não pra vazão). Pra dezenas de GB o caminho certo é VPN paga, não isto.
# ═══════════════════════════════════════════════════════════════════════════
{ config, ... }:

{
  services.tor = {
    enable = config.my.services.tor;
    client.enable = true; # é o que abre o SOCKS5 em 127.0.0.1:9050
    settings = {
      ClientOnly = true; # trava o papel: nunca relay, nunca exit
      SafeSocks = true; # DNS resolvido fora do Tor = erro, não vazamento silencioso
    };
  };
}
