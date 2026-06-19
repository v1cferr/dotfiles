#!/bin/sh
# ============================================================================
#  Habilita FULL-TUNNEL no WireGuard do roteador OpenWrt (Cudy WR3000, fw4)
# ----------------------------------------------------------------------------
#  Adiciona o encaminhamento de firewall  wg -> wan  (o que faltava). A zona
#  `wan` já tem masq=1, então o NAT acontece sozinho; aqui só LIBERAMOS o
#  forward. Quem decide usar a internet de casa é o AllowedIPs do CLIENTE.
#
#  Objetivo: de fora (ex: 4G mais lento), navegar pela internet de CASA.
#  Aditivo e IDEMPOTENTE (não duplica se já existir). Backup + `fw4 check`.
#
#  RODA NO ROTEADOR, COMO ROOT. Uso a partir do desktop (precisa de tty p/ sudo):
#    scp -O ~/dotfiles/scripts/wireguard/enable-fulltunnel-router.sh v1cferr@192.168.1.1:/tmp/wg-ft.sh
#    ssh -t v1cferr@192.168.1.1 'sudo sh /tmp/wg-ft.sh'
#
#  Depois, no CLIENTE (celular/notebook), ajuste o perfil WireGuard:
#    AllowedIPs = 0.0.0.0/0, ::/0
#    DNS        = 192.168.1.1        (AdBlock/DoH do router + split-DNS)
# ============================================================================
set -eu

say() { echo "==> $*"; }

say "Backup de firewall"
cp /etc/config/firewall /etc/config/firewall.fulltun-bak

# Idempotência: já existe forwarding wg -> wan?
have=0; idx=0
while uci -q get "firewall.@forwarding[$idx]" >/dev/null 2>&1; do
  s=$(uci -q get "firewall.@forwarding[$idx].src"  2>/dev/null || true)
  d=$(uci -q get "firewall.@forwarding[$idx].dest" 2>/dev/null || true)
  [ "$s" = "wg" ] && [ "$d" = "wan" ] && have=1
  idx=$((idx + 1))
done
if [ "$have" = "1" ]; then
  say "Forwarding wg -> wan JÁ existe. Nada a fazer."
  exit 0
fi

say "Adicionando forwarding wg -> wan"
uci add firewall forwarding >/dev/null
uci set firewall.@forwarding[-1].src=wg
uci set firewall.@forwarding[-1].dest=wan
uci commit firewall

say "Validando (fw4 check)"
if ! fw4 check >/dev/null 2>&1; then
  cp /etc/config/firewall.fulltun-bak /etc/config/firewall
  uci commit firewall
  /etc/init.d/firewall reload || true
  echo "ERRO: fw4 check falhou — config revertida." >&2
  exit 1
fi
/etc/init.d/firewall reload

say "OK. Forwardings agora:"
uci show firewall | grep -i forwarding
echo
echo "Agora ajuste o CLIENTE: AllowedIPs = 0.0.0.0/0, ::/0  e  DNS = 192.168.1.1"
