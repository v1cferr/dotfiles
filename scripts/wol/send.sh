#!/usr/bin/env bash
# ============================================================================
#  Envia um magic packet (Wake-on-LAN) para um host
# ----------------------------------------------------------------------------
#  Uso:  send.sh <MAC> [broadcast-ip]
#  Ex.:  send.sh 7c:10:c9:a1:f4:e5            # broadcast geral
#        send.sh 7c:10:c9:a1:f4:e5 192.168.1.255
#
#  Para ACORDAR ESTE desktop, rode isto de OUTRA máquina (ou use o app do
#  celular / o OpenWrt). O desktop precisa estar com WoL habilitado
#  (scripts/wol/deploy.sh) e ligado na tomada.
#
#  Sem dependências extras — usa python3.
# ============================================================================
set -euo pipefail
MAC="${1:?uso: $0 <MAC> [broadcast-ip]}"
BCAST="${2:-255.255.255.255}"

python3 - "${MAC}" "${BCAST}" <<'PY'
import socket, sys
mac = sys.argv[1].replace(':', '').replace('-', '')
assert len(mac) == 12, "MAC inválido"
packet = b'\xff' * 6 + bytes.fromhex(mac) * 16
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
s.sendto(packet, (sys.argv[2], 9))
print(f"magic packet enviado para {sys.argv[1]} via {sys.argv[2]}:9")
PY
