#!/usr/bin/env bash
# ============================================================================
#  Acorda o desktop disparando o WoL PELO router OpenWrt (sempre ligado)
# ----------------------------------------------------------------------------
#  Roda em QUALQUER máquina que alcance o router (LAN ou via VPN) — não no
#  próprio desktop (que estará desligado). O router roda /usr/bin/wake-desktop
#  (etherwake) sem senha (NOPASSWD), então é só um SSH não-interativo.
#
#  Pré-req: chave SSH autorizada no router (ssh-copy-id v1cferr@192.168.1.1)
#  e o setup do lado do router (ver README.md > Router OpenWrt).
#
#  Uso:  wake-via-router.sh [user@host-do-router]
# ============================================================================
set -euo pipefail
ROUTER="${1:-v1cferr@192.168.1.1}"

if ssh -o BatchMode=yes -o ConnectTimeout=8 "${ROUTER}" sudo -n /usr/bin/wake-desktop; then
    echo "✓ magic packet disparado pelo router (${ROUTER}) para o desktop 7c:10:c9:a1:f4:e5"
else
    echo "✗ falhou — confira a chave SSH no router e o wake-desktop/NOPASSWD (README.md)" >&2
    exit 1
fi
