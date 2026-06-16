#!/bin/bash
# ============================================================================
#  Conecta à VPN da FAI.UFSCAR (SonicWALL/netExtender) de um desktop ACESSADO
#  REMOTAMENTE por SSH — sem se trancar pra fora.
# ----------------------------------------------------------------------------
#  A VPN pode ser full-tunnel (reescreve a rota default). Pra não perder o SSH
#  de entrada, este wrapper:
#    1. FIXA uma host-route para o(s) peer(s) da sessão SSH (porta 2222) pela
#       WAN de casa — o tráfego de volta da sua sessão nunca entra no túnel;
#    2. arma um DEAD-MAN (timer transiente do systemd, sobrevive ao fim da
#       sessão SSH): em ${WINDOW}s desconecta a VPN e restaura a rota default
#       sozinho, a menos que você cancele (caso algo trave de fora);
#    3. conecta a VPN (perfil salvo).
#
#  Observação feliz: no nosso caso o peer SSH == gateway da VPN
#  (200.133.233.101), que o próprio netExtender já mantém pela física — então
#  a sessão tende a sobreviver mesmo sem o pin. O pin/dead-man são seguro extra.
#
#  Uso (no desktop, terminal real — pede senha):  sudo bash $0
#  Manter a VPN depois de confirmar:              sudo systemctl stop fai-vpn-deadman.timer
#  Desconectar na mão:                            sudo systemctl stop NEService; sudo pkill -f netExtender
# ============================================================================
set -u

PROFILE="FAI.UFSCAR"
UNIT="fai-vpn-deadman"
WINDOW="600"   # 10 min de janela do dead-man

[ "$(id -u)" = "0" ] || { echo "Rode com sudo: sudo bash $0" >&2; exit 1; }
command -v netExtender >/dev/null || { echo "netExtender não encontrado (yay -S netextender)" >&2; exit 1; }

# 1) snapshot da rota default
GW=$(ip route show default | awk '/^default/{print $3; exit}')
DEV=$(ip route show default | awk '/^default/{print $5; exit}')
[ -n "$GW" ] && [ -n "$DEV" ] || { echo "Não achei a rota default. Abortando." >&2; exit 1; }
echo "default: via $GW dev $DEV"

# 2) fixar host-route para o(s) peer(s) SSH na :2222 (protege a sessão)
PEERS=$(ss -Htn state established '( sport = :2222 )' 2>/dev/null | awk '{print $NF}' | sed -E 's/:[0-9]+$//' | sort -u)
echo "peers SSH protegidos: ${PEERS:-<nenhum>}"
for p in $PEERS; do
    ip route replace "$p/32" via "$GW" dev "$DEV" && echo "  pin $p -> via $GW dev $DEV"
done

# 3) dead-man: TIMER TRANSIENTE do systemd. Sobrevive ao fim da sessão SSH, ao
#    contrário de um setsid (que o escopo de sessão do systemd mata no logout, e
#    por isso a proteção não funcionava num acesso remoto). Em ${WINDOW}s
#    desconecta a VPN e restaura a rota default — a menos que você cancele.
systemctl stop "${UNIT}.timer" 2>/dev/null
systemctl reset-failed "${UNIT}.service" "${UNIT}.timer" 2>/dev/null
if systemd-run --quiet --collect --unit="$UNIT" --on-active="$WINDOW" \
    /bin/bash -c "logger -t ${UNIT} 'DISPAROU: derrubando VPN e restaurando rota default'; pkill -f netExtender 2>/dev/null; systemctl stop NEService 2>/dev/null; ip route replace default via ${GW} dev ${DEV} 2>/dev/null"; then
    echo "dead-man armado ($((WINDOW/60)) min, timer ${UNIT}). Se a sessão travar, a VPN cai e a rota volta sozinha."
    echo "  >>> deu tudo certo e quer MANTER a VPN?  sudo systemctl stop ${UNIT}.timer"
else
    echo "AVISO: não consegui armar o dead-man (systemd-run falhou) — conectando SEM rede de proteção." >&2
fi

# 4) conectar
systemctl is-active --quiet NEService || systemctl start NEService
echo ">>> conectando à VPN ${PROFILE} (vai pedir a senha da VPN)..."
netExtender connect "$PROFILE"
