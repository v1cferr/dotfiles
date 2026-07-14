#!/bin/sh
# ============================================================================
#  VPN gateway da FAI — configuração do ROTEADOR (OpenWrt)
# ----------------------------------------------------------------------------
#  RODE ISTO NO ROTEADOR (como root), não no desktop:
#      scp netextender/router/fai-vpn-gateway.sh root@192.168.1.1:/tmp/
#      ssh root@192.168.1.1 sh /tmp/fai-vpn-gateway.sh
#  ou cole o conteúdo direto numa sessão `ssh` no roteador (sudo -s / root).
#
#  O que faz:
#   1) Lease DHCP fixo .40 para a máquina do César (arch-cesar).
#   2) Rotas estáticas dos subnets da FAI apontando pro desktop (.10), que roda
#      a VPN. Assim QUALQUER dispositivo da LAN alcança a FAI sem configurar
#      nada nele — desde que o desktop esteja ligado e com a VPN conectada.
#
#  Idempotente: usa seções UCI nomeadas; re-rodar não duplica.
#  Requisito no desktop: `vpn connect fai` (o gateway NAT sobe junto com o túnel).
# ============================================================================
set -e

GW=192.168.1.10   # desktop (.10) que roda a VPN da FAI

# 1) Lease fixo .40 para a máquina do César --------------------------------
uci set dhcp.arch_cesar=host
uci set dhcp.arch_cesar.name='arch-cesar'
uci set dhcp.arch_cesar.mac='74:56:3C:F2:B6:48'
uci set dhcp.arch_cesar.ip='192.168.1.40'
uci commit dhcp

# 2) Rotas estáticas: subnets da FAI -> desktop (.10) ----------------------
add_route() {  # $1=nome  $2=target  $3=netmask
    uci set network."$1"=route
    uci set network."$1".interface='lan'
    uci set network."$1".target="$2"
    uci set network."$1".netmask="$3"
    uci set network."$1".gateway="$GW"
}
add_route fai_r1 192.168.90.0    255.255.255.0
add_route fai_r2 192.168.100.0   255.255.255.0
add_route fai_r3 192.168.110.0   255.255.255.0
add_route fai_r4 192.168.130.0   255.255.255.0
add_route fai_r5 192.168.223.0   255.255.255.0
add_route fai_r6 200.136.209.128 255.255.255.128
uci commit network

# 3) Aplica ----------------------------------------------------------------
/etc/init.d/dnsmasq reload
/etc/init.d/network reload

echo "OK: lease .40 (arch-cesar) + 6 rotas da FAI via ${GW} aplicados."
echo "Obs.: pra máquina do César pegar o .40, reconecte a rede dela (ou reboot)."
