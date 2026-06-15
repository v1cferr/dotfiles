#!/bin/sh
# ============================================================================
#  WireGuard server no roteador OpenWrt (Cudy WR3000, OpenWrt 25.x / fw4)
# ----------------------------------------------------------------------------
#  RODA NO ROTEADOR, COMO ROOT. Aditivo (não remove os port-forwards 80/443/
#  2222 existentes). Blindado contra lockout:
#    - backup de /etc/config/{network,firewall} antes de tudo;
#    - DEAD-MAN SWITCH: reverte sozinho em ${DEADMAN_SECS}s se você não cancelar
#      (a sessão SSH atual passa pelo router — se cair, isto te salva);
#    - `fw4 check` valida o ruleset ANTES de confiar; se falhar, reverte na hora;
#    - usa `reload` (não restart) — conntrack preserva conexões estabelecidas.
#
#  Objetivo: acordar/acessar a casa de fora via VPN, sem expor login nenhum.
#  Túnel split: o cliente só roteia 192.168.1.0/24 (a casa) pelo WireGuard.
#
#  Uso (a partir do desktop, que alcança o router):
#    scp ~/dotfiles/scripts/wireguard/deploy-router.sh v1cferr@192.168.1.1:/tmp/wg-deploy.sh
#    ssh -t v1cferr@192.168.1.1 'su root -c "sh /tmp/wg-deploy.sh"'
#
#  Depois de confirmar que a sessão sobreviveu, CANCELE o dead-man (no router):
#    rm -f /tmp/wg-deadman.active
# ============================================================================
set -eu

WG_IF="wg0"
WG_PORT="51820"          # porta UDP de escuta (WireGuard é mudo p/ quem não tem chave)
WG_NET="10.10.10"        # sub-rede do túnel: router=.1, notebook=.2, celular=.3
PUBHOST="ssh.v1cferr.dev"  # endpoint público (DDNS já mantém atualizado)
DEADMAN_SECS="600"       # 10 min até o auto-revert
CLIENTS_OUT="/root/wg-clients.conf"

say() { echo "==> $*"; }

say "[1/7] Backup de network e firewall"
cp /etc/config/network  /etc/config/network.wg-bak
cp /etc/config/firewall /etc/config/firewall.wg-bak

say "[2/7] Armando dead-man switch (revert em ${DEADMAN_SECS}s se não cancelar)"
touch /tmp/wg-deadman.active
setsid sh -c '
  sleep '"${DEADMAN_SECS}"'
  [ -f /tmp/wg-deadman.active ] || exit 0
  cp /etc/config/network.wg-bak  /etc/config/network
  cp /etc/config/firewall.wg-bak /etc/config/firewall
  /etc/init.d/network reload
  /etc/init.d/firewall reload
  logger -t wg-deadman "DEAD-MAN DISPAROU: config WireGuard revertida"
' >/dev/null 2>&1 &
echo "    cancelar com:  rm -f /tmp/wg-deadman.active"

# Aborta cedo, ainda dentro da janela do dead-man, sem deixar uci sujo.
abort() {
  echo "ERRO: $*" >&2
  uci -q revert network || true
  uci -q revert firewall || true
  rm -f /tmp/wg-deadman.active
  exit 1
}

say "[3/7] Idempotência: ${WG_IF} já existe?"
if uci -q get "network.${WG_IF}" >/dev/null; then
  abort "network.${WG_IF} já existe — remova antes de reaplicar (evita duplicar peers)."
fi

say "[4/7] Instalando WireGuard via apk"
apk update >/dev/null 2>&1 || true
apk add wireguard-tools kmod-wireguard luci-proto-wireguard || abort "apk add falhou"

say "[5/7] Gerando chaves"
umask 077
SRV_PRIV=$(wg genkey); SRV_PUB=$(printf '%s' "$SRV_PRIV" | wg pubkey)
LAP_PRIV=$(wg genkey); LAP_PUB=$(printf '%s' "$LAP_PRIV" | wg pubkey)
PHN_PRIV=$(wg genkey); PHN_PUB=$(printf '%s' "$PHN_PRIV" | wg pubkey)

say "[6/7] Configurando interface + firewall (uci)"
# --- interface wg0 ---
uci set "network.${WG_IF}=interface"
uci set "network.${WG_IF}.proto=wireguard"
uci set "network.${WG_IF}.private_key=${SRV_PRIV}"
uci set "network.${WG_IF}.listen_port=${WG_PORT}"
uci -q delete "network.${WG_IF}.addresses" || true
uci add_list "network.${WG_IF}.addresses=${WG_NET}.1/24"

# --- peer: notebook ---
uci add network "wireguard_${WG_IF}" >/dev/null
uci set "network.@wireguard_${WG_IF}[-1].public_key=${LAP_PUB}"
uci set "network.@wireguard_${WG_IF}[-1].description=notebook"
uci add_list "network.@wireguard_${WG_IF}[-1].allowed_ips=${WG_NET}.2/32"

# --- peer: celular ---
uci add network "wireguard_${WG_IF}" >/dev/null
uci set "network.@wireguard_${WG_IF}[-1].public_key=${PHN_PUB}"
uci set "network.@wireguard_${WG_IF}[-1].description=celular"
uci add_list "network.@wireguard_${WG_IF}[-1].allowed_ips=${WG_NET}.3/32"

# --- firewall: zona wg ---
uci add firewall zone >/dev/null
uci set "firewall.@zone[-1].name=wg"
uci set "firewall.@zone[-1].input=ACCEPT"
uci set "firewall.@zone[-1].output=ACCEPT"
uci set "firewall.@zone[-1].forward=ACCEPT"
uci add_list "firewall.@zone[-1].network=${WG_IF}"

# --- firewall: forward wg -> lan (alcançar o desktop .10 e o router .1) ---
uci add firewall forwarding >/dev/null
uci set "firewall.@forwarding[-1].src=wg"
uci set "firewall.@forwarding[-1].dest=lan"

# --- firewall: liberar a porta UDP do WG na WAN ---
uci add firewall rule >/dev/null
uci set "firewall.@rule[-1].name=Allow-WireGuard"
uci set "firewall.@rule[-1].src=wan"
uci set "firewall.@rule[-1].proto=udp"
uci set "firewall.@rule[-1].dest_port=${WG_PORT}"
uci set "firewall.@rule[-1].target=ACCEPT"

say "[7/7] Validando (fw4 check) e aplicando"
uci commit network
uci commit firewall
if ! fw4 check >/dev/null 2>&1; then
  cp /etc/config/network.wg-bak  /etc/config/network
  cp /etc/config/firewall.wg-bak /etc/config/firewall
  uci commit
  /etc/init.d/network reload || true
  /etc/init.d/firewall reload || true
  abort "fw4 check falhou — config revertida na hora."
fi
/etc/init.d/network reload
/etc/init.d/firewall reload

# --- configs dos clientes (também salvas em ${CLIENTS_OUT}, modo 600) ---
ALLOWED="192.168.1.0/24, ${WG_NET}.0/24"
{
cat <<EOF
===== NOTEBOOK  (salve como casa-wg.conf) =====
[Interface]
PrivateKey = ${LAP_PRIV}
Address = ${WG_NET}.2/32

[Peer]
PublicKey = ${SRV_PUB}
Endpoint = ${PUBHOST}:${WG_PORT}
AllowedIPs = ${ALLOWED}
PersistentKeepalive = 25

===== CELULAR  (importe por QR: qrencode -t ansiutf8 < celular.conf) =====
[Interface]
PrivateKey = ${PHN_PRIV}
Address = ${WG_NET}.3/32

[Peer]
PublicKey = ${SRV_PUB}
Endpoint = ${PUBHOST}:${WG_PORT}
AllowedIPs = ${ALLOWED}
PersistentKeepalive = 25
EOF
} | tee "${CLIENTS_OUT}" >/dev/null
chmod 600 "${CLIENTS_OUT}"

cat <<EOF

############################################################################
#  WireGuard NO AR (porta UDP ${WG_PORT}). Servidor pubkey: ${SRV_PUB}
#
#  >>> A sessão SSH sobreviveu? Se SIM, CANCELE o dead-man AGORA:
#          rm -f /tmp/wg-deadman.active
#      (senão ele reverte tudo em ${DEADMAN_SECS}s)
#
#  Configs dos clientes salvas em ${CLIENTS_OUT} (contém CHAVES PRIVADAS —
#  copie pro notebook/celular e depois apague: rm -f ${CLIENTS_OUT}).
############################################################################

EOF
cat "${CLIENTS_OUT}"
