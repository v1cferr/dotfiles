#!/bin/sh
# It opens the Moonlight ports on the OpenWrt, restricted to UFSCar's blocks. IT RUNS ON THE
# ROUTER, in 2 steps, and it needs a password. The commands and why: docs/notes/network/network.md
set -eu

LAN_HOST='192.168.1.10' # the Sunshine host (a fixed DHCP lease)
BACKUP=/tmp/firewall.bak.$$
WATCHDOG_SECS=600 # 10 min until the automatic rollback

# ONE REDIRECT PER SOURCE: in fw4 a redirect's `src_ip` CANNOT be a list, and uci ACCEPTS it
# silently while fw4 discards the section. Do NOT swap it for 0.0.0.0/0 (no CGNAT here).
SOURCES='Campus=200.133.224.0/20 FAI=200.136.192.0/21'

# How many rules must exist in the EFFECTIVE ruleset: 4 port groups times 2 sources. Without
# this number the script cannot tell whether it worked.
EXPECTED=8

# The safety net: if this shell dies, if the verification fails, or if the change locks you out,
# /etc/config/firewall goes back.
cp /etc/config/firewall "$BACKUP"
# shellcheck disable=SC2064 # $BACKUP has to expand NOW, not when the trap fires
trap "echo '>>> reverting'; cp '$BACKUP' /etc/config/firewall; /etc/init.d/firewall reload" EXIT
# `nohup … &` and NOT a subshell: the watchdog exists for the case where the change drops your
# SSH, and that is exactly when a subshell would take the SIGHUP and die with it.
nohup sh -c "sleep $WATCHDOG_SECS; cp '$BACKUP' /etc/config/firewall; /etc/init.d/firewall reload" \
	>/dev/null 2>&1 &
WATCHDOG=$!
echo "watchdog $WATCHDOG armed: an automatic rollback in ${WATCHDOG_SECS}s"

# Cleanup, BACK TO FRONT (deleting by index reindexes what follows) and counting SECTIONS, not
# lines: `uci show` yields ~8 lines per redirect, so a line count loops for nothing.
i=$(uci show firewall | grep -c '^firewall\.@redirect\[[0-9]*\]=redirect$' || true)
while [ "$i" -gt 0 ]; do
	i=$((i - 1))
	case "$(uci -q get "firewall.@redirect[$i].name" || true)" in
	Moonlight-*)
		echo "removing the old redirect: $(uci -q get "firewall.@redirect[$i].name")"
		uci delete "firewall.@redirect[$i]"
		;;
	esac
done

# The ports were checked against the Sunshine build in use, not copied from a blog: the UDP
# 48002 "mic" does not exist in this version, and 47990 (the web UI) stays out on purpose.
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
		uci set "firewall.$s.src_ip=$cidr" # `set`, NEVER `add_list`; see the top
		echo "created: $base-$label ($proto $ports from $cidr)"
	done
}

add_redirect Moonlight-HTTPS tcp 47984        # an already paired host comes in through here
add_redirect Moonlight-HTTP tcp 47989         # /serverinfo and PIN pairing
add_redirect Moonlight-RTSP tcp 48010         # the session's negotiation
add_redirect Moonlight-Stream udp 47998-48000 # video, audio and control

uci commit firewall
/etc/init.d/firewall reload

# It verifies AGAINST THE EFFECTIVE nftables, never `uci show`: that was the 1st version's
# mistake, printing "OK, permanent" with ZERO rules live. See docs/notes/network/network.md
echo
echo "=== the effective dstnat_wan ==="
nft list chain inet fw4 dstnat_wan
got=$(nft list chain inet fw4 dstnat_wan | grep -c 'Moonlight' || true)
echo
if [ "$got" -ne "$EXPECTED" ]; then
	echo "FAILED: $got Moonlight rules in the ruleset, expected $EXPECTED." >&2
	echo "Look for 'skipped due to invalid options' in the reload output above." >&2
	exit 1 # it fires the trap, hence the rollback
fi
echo "OK: $got/$EXPECTED Moonlight rules ACTIVE in the ruleset."

# Getting here means it applied AND was verified. It disarms both safety nets.
kill "$WATCHDOG" 2>/dev/null || true
trap - EXIT
rm -f "$BACKUP"
echo "watchdog disarmed, the change is permanent."
