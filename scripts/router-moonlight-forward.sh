#!/bin/sh
# Abre as portas do Moonlight no OpenWrt, restritas aos blocos da UFSCar.
#
# RODA NO ROTEADOR, não aqui, e em DOIS passos:
#
#   ssh v1cferr@192.168.1.1 'cat > /tmp/ml.sh' < scripts/router-moonlight-forward.sh
#   ssh -t v1cferr@192.168.1.1 'sudo sh /tmp/ml.sh; rm -f /tmp/ml.sh'
#
# É a metade que o Nix não alcança — ver o cabeçalho de system/net/router.nix. A outra
# metade (o firewall do HOST) é declarativa e vive em system/services/sunshine.nix; as
# duas listas de origem TÊM que casar, senão o roteador encaminha e o host derruba.
#
# ⚠️ POR QUE DOIS PASSOS, e não o óbvio `ssh … 'sudo sh -s' < script`: com o script
# entrando pelo STDIN, o sudo não tem por onde pedir a senha — o stdin já é o script, não
# o terminal — e ele falha sem sequer perguntar. Copiar primeiro e executar depois libera
# o stdin pro prompt, e é por isso que o segundo comando leva `-t` (força o pty).
#
# ⚠️ E POR QUE PRECISA DE SENHA: o sudoers deste roteador dá NOPASSWD só pra `/sbin/uci`,
# `/usr/sbin/nft`, `/sbin/reboot` e `/etc/init.d/dnsmasq` — medido em 10/08/2026 com
# `sudo -l`. O `/etc/init.d/firewall reload` do fim NÃO está na lista, então a senha é
# pedida uma vez. É também por isso que `root@` não funciona: o dropbear tem
# `RootLogin='off'` e `RootPasswordAuth='off'` (router/uci/dropbear.conf).
#
# `/tmp` no OpenWrt é tmpfs (RAM): copiar pra lá não gasta os ~1.4 MB livres de flash.
#
# IDEMPOTENTE: apaga qualquer redirect `Moonlight-*` anterior antes de criar. Rodar duas
# vezes não empilha duplicata.
set -eu

LAN_HOST='192.168.1.10' # host do Sunshine (lease fixa no DHCP)
BACKUP=/tmp/firewall.bak.$$
WATCHDOG_SECS=600 # 10 min até o rollback automático

# ── De onde se aceita ───────────────────────────────────────────────────────
# ⚠️ UMA REDIRECT POR ORIGEM, e isso NÃO é escolha de estilo: no fw4 o `src_ip` de uma
# `redirect` **não pode ser lista** (em `rule` pode — foi daí que a versão errada saiu).
# Medido em 10/08/2026, e o modo de falha é o pior possível:
#     Section @redirect[3] (Moonlight-HTTPS) option 'src_ip' must not be a list
#     Section @redirect[3] (Moonlight-HTTPS) skipped due to invalid options
# O `uci commit` ACEITA, o `uci show` EXIBE a redirect bonitinha, e o fw4 a DESCARTA
# na hora de gerar o ruleset. Ou seja: config presente, efeito nenhum.
#
# Os dois blocos são da UFSCar (registro.br, CNPJ 45.358.058/0001-40). O rótulo entra no
# nome da redirect só pra ficar legível no LuCI.
#
# ⚠️ NÃO trocar por `0.0.0.0/0`. A casa NÃO está atrás de CGNAT — medido em 10/08/2026, a
# 2222 responde de Áustria, Canadá e Irã — então isso ali significa o planeta.
SOURCES='Campus=200.133.224.0/20 FAI=200.136.192.0/21'

# Quantas regras têm que existir no ruleset EFETIVO no fim. 4 grupos de porta × 2 origens.
# É o número que o passo de verificação cobra; sem ele o script não sabe se funcionou.
EXPECTED=8

# ── Rede de segurança (commit-confirm pobre) ────────────────────────────────
# Se este shell morrer no meio, se a verificação final reprovar, ou se a mudança te
# trancar fora, o /etc/config/firewall volta ao que era.
cp /etc/config/firewall "$BACKUP"
# shellcheck disable=SC2064 # $BACKUP tem que expandir AGORA, não na saída do trap
trap "echo '>>> revertendo'; cp '$BACKUP' /etc/config/firewall; /etc/init.d/firewall reload" EXIT
#
# `nohup … &` e não um subshell `( … ) &`: o watchdog existe justamente pro caso em que a
# mudança derruba a sua SSH, e é aí que o subshell levaria SIGHUP junto e morreria — a
# rede de segurança sumiria exatamente no acidente que ela deveria cobrir.
nohup sh -c "sleep $WATCHDOG_SECS; cp '$BACKUP' /etc/config/firewall; /etc/init.d/firewall reload" \
	>/dev/null 2>&1 &
WATCHDOG=$!
echo "watchdog $WATCHDOG armado: rollback automático em ${WATCHDOG_SECS}s"

# ── Limpa aplicações anteriores ─────────────────────────────────────────────
# De trás pra frente: apagar por índice reindexa o que vem depois, e iterar pra frente
# pula uma entrada a cada remoção. Erro clássico de UCI.
#
# Conta SEÇÕES (`…@redirect[N]=redirect`), não linhas: cada redirect rende ~8 linhas no
# `uci show`, então contar linhas dá um teto inflado. Não quebraria — índice inexistente
# só devolve vazio e não casa o `case` — mas iteraria dezenas de voltas à toa.
i=$(uci show firewall | grep -c '^firewall\.@redirect\[[0-9]*\]=redirect$' || true)
while [ "$i" -gt 0 ]; do
	i=$((i - 1))
	case "$(uci -q get "firewall.@redirect[$i].name" || true)" in
	Moonlight-*)
		echo "removendo redirect antiga: $(uci -q get "firewall.@redirect[$i].name")"
		uci delete "firewall.@redirect[$i]"
		;;
	esac
done

# ── Cria as redirects ───────────────────────────────────────────────────────
# Portas conferidas no build do Sunshine em uso (2026.516.143833), não copiadas de blog:
# a UDP 48002 ("mic") que quase toda lista inclui NÃO existe nesta versão.
# A 47990 (web UI / painel admin) fica DE FORA de propósito — ver sunshine.nix.
add_redirect() {
	base=$1
	proto=$2
	ports=$3
	for entry in $SOURCES; do
		label=${entry%%=*}
		cidr=${entry#*=}
		s=$(uci add firewall redirect)
		uci set "firewall.$s.name=$base-$label"
		uci set "firewall.$s.src=wan"
		uci set "firewall.$s.dest=lan"
		uci set "firewall.$s.dest_ip=$LAN_HOST"
		uci set "firewall.$s.proto=$proto"
		uci set "firewall.$s.src_dport=$ports"
		uci set "firewall.$s.dest_port=$ports"
		uci set "firewall.$s.target=DNAT"
		uci set "firewall.$s.src_ip=$cidr" # `set`, NUNCA `add_list` — ver o topo
		echo "criada: $base-$label ($proto $ports de $cidr)"
	done
}

add_redirect Moonlight-HTTPS tcp 47984        # host já pareado entra por aqui
add_redirect Moonlight-HTTP tcp 47989         # /serverinfo e pareamento por PIN
add_redirect Moonlight-RTSP tcp 48010         # negociação da sessão
add_redirect Moonlight-Stream udp 47998-48000 # vídeo, áudio e controle

uci commit firewall
/etc/init.d/firewall reload

# ── Verifica CONTRA O RULESET EFETIVO ───────────────────────────────────────
# ⚠️ NÃO conferir com `uci show`: foi exatamente esse o erro da 1ª versão deste script.
# O `uci show` lê a CONFIG, e a config estava lá — o fw4 é que descartava as seções por
# `src_ip` inválido. O script imprimia "OK, mudança permanente" com ZERO regras no ar.
# A única fonte de verdade é o nftables gerado.
echo
echo "=== dstnat_wan efetivo ==="
nft list chain inet fw4 dstnat_wan
got=$(nft list chain inet fw4 dstnat_wan | grep -c 'Moonlight' || true)
echo
if [ "$got" -ne "$EXPECTED" ]; then
	echo "FALHOU: $got regras Moonlight no ruleset, esperado $EXPECTED." >&2
	echo "Procure por 'skipped due to invalid options' na saída do reload acima." >&2
	exit 1 # dispara o trap → rollback
fi
echo "OK: $got/$EXPECTED regras Moonlight ATIVAS no ruleset."

# Chegou aqui = aplicou E foi verificado. Desarma as duas redes de segurança.
kill "$WATCHDOG" 2>/dev/null || true
trap - EXIT
rm -f "$BACKUP"
echo "watchdog desarmado, mudança permanente."
