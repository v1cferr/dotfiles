#!/bin/sh
# Diagnóstico read/▶ do estado do WireGuard no router. Roda como root.
echo "===== network.wg0 (config) ====="
uci show network.wg0 2>&1
echo "===== peers wireguard_wg0 ====="
uci show network 2>&1 | grep wireguard_wg0 || echo "(nenhum peer)"
echo "===== firewall: zona/forward/rule wg ====="
uci show firewall 2>&1 | grep -iE "name='wg'|src='wg'|dest='wg'|Allow-WireGuard" || echo "(nenhuma entrada wg)"
echo "===== dead-man rodando? ====="
ps w 2>/dev/null | grep -E "sleep 600|wg-deadman" | grep -v grep || echo "(nenhum)"
echo "===== tentando ifup wg0 ====="
ifup wg0 2>&1
sleep 2
echo "===== device wg0? ====="
ip -br addr show wg0 2>&1
echo "===== wg show (estado do túnel) ====="
wg show 2>&1
echo "===== logread netifd/wireguard (últimas linhas) ====="
logread 2>/dev/null | grep -iE "netifd|wireguard|wg0|interface 'wg0'" | tail -20
