#!/bin/sh
# It opens the Moonlight ports on the OpenWrt, restricted to UFSCar's blocks.
#
# IT RUNS ON THE ROUTER, not here, and in TWO steps:
#
#   ssh v1cferr@192.168.1.1 'cat > /tmp/ml.sh' < scripts/router-moonlight-forward.sh
#   ssh -t v1cferr@192.168.1.1 'sudo sh /tmp/ml.sh; rm -f /tmp/ml.sh'
#
# It is the half Nix does not reach; see the header of system/net/router.nix. The other half
# (the HOST's firewall) is declarative and lives in system/services/sunshine.nix, and the two
# source lists HAVE to match, otherwise the router forwards and the host drops.
#
# WHY TWO STEPS, and not the obvious `ssh … 'sudo sh -s' < script`: with the script coming in
# through STDIN, sudo has no way to ask for the password (stdin is already the script, not the
# terminal) and it fails without even asking. Copying first and running afterwards frees stdin
# for the prompt, and that is why the second command carries `-t` (it forces a pty).
#
# AND WHY IT NEEDS A PASSWORD: this router's sudoers gives NOPASSWD only to `/sbin/uci`,
# `/usr/sbin/nft`, `/sbin/reboot` and `/etc/init.d/dnsmasq`, measured on 10/08/2026 with
# `sudo -l`. The `/etc/init.d/firewall reload` at the end is NOT on that list, so the password is
# asked once. It is also why `root@` does not work: dropbear has `RootLogin='off'` and
# `RootPasswordAuth='off'` (router/uci/dropbear.conf).
#
# `/tmp` on OpenWrt is tmpfs (RAM): copying there does not spend the ~1.4 MB of free flash.
#
# IDEMPOTENT: it deletes any previous `Moonlight-*` redirect before creating. Running it twice
# does not stack duplicates.
set -eu

LAN_HOST='192.168.1.10' # the Sunshine host (a fixed DHCP lease)
BACKUP=/tmp/firewall.bak.$$
WATCHDOG_SECS=600 # 10 min until the automatic rollback

# ── Where connections are accepted from ─────────────────────────────────────
# ONE REDIRECT PER SOURCE, and that is NOT a style choice: in fw4 a `redirect`'s `src_ip`
# **cannot be a list** (in a `rule` it can, which is where the wrong version came from).
# Measured on 10/08/2026, and the failure mode is the worst possible:
#     Section @redirect[3] (Moonlight-HTTPS) option 'src_ip' must not be a list
#     Section @redirect[3] (Moonlight-HTTPS) skipped due to invalid options
# The `uci commit` ACCEPTS it, `uci show` DISPLAYS the redirect nicely, and fw4 DISCARDS it when
# generating the ruleset. Which means: the config is present, the effect is none.
#
# Both blocks are UFSCar's (registro.br, CNPJ 45.358.058/0001-40). The label goes into the
# redirect's name only to stay readable in LuCI.
#
# Do NOT swap it for `0.0.0.0/0`. The house is NOT behind CGNAT (measured on 10/08/2026, port
# 2222 answers from Austria, Canada and Iran), so that would mean the planet.
SOURCES='Campus=200.133.224.0/20 FAI=200.136.192.0/21'

# How many rules have to exist in the EFFECTIVE ruleset at the end. 4 port groups times 2
# sources. It is the number the verification step demands; without it the script does not know
# whether it worked.
EXPECTED=8

# ── The safety net (a poor man's commit-confirm) ────────────────────────────
# If this shell dies halfway, if the final verification fails, or if the change locks you out,
# /etc/config/firewall goes back to what it was.
cp /etc/config/firewall "$BACKUP"
# shellcheck disable=SC2064 # $BACKUP has to expand NOW, not when the trap fires
trap "echo '>>> reverting'; cp '$BACKUP' /etc/config/firewall; /etc/init.d/firewall reload" EXIT
#
# `nohup … &` and not a `( … ) &` subshell: the watchdog exists precisely for the case where the
# change drops your SSH, and that is when the subshell would take the SIGHUP along and die, so
# the safety net would disappear in exactly the accident it was supposed to cover.
nohup sh -c "sleep $WATCHDOG_SECS; cp '$BACKUP' /etc/config/firewall; /etc/init.d/firewall reload" \
	>/dev/null 2>&1 &
WATCHDOG=$!
echo "watchdog $WATCHDOG armed: an automatic rollback in ${WATCHDOG_SECS}s"

# ── It cleans up previous applications ──────────────────────────────────────
# Back to front: deleting by index reindexes what comes after, and iterating forward skips an
# entry on every removal. The classic UCI mistake.
#
# It counts SECTIONS (`…@redirect[N]=redirect`), not lines: each redirect yields ~8 lines in
# `uci show`, so counting lines gives an inflated ceiling. It would not break (a nonexistent
# index just returns empty and does not match the `case`), but it would loop dozens of times for
# nothing.
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

# ── It creates the redirects ────────────────────────────────────────────────
# The ports were checked against the Sunshine build in use (2026.516.143833), not copied from a
# blog: the UDP 48002 ("mic") that almost every list includes does NOT exist in this version.
# 47990 (the web UI / admin panel) stays OUT on purpose; see sunshine.nix.
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

# ── It verifies AGAINST THE EFFECTIVE RULESET ───────────────────────────────
# Do NOT check with `uci show`: that was exactly this script's 1st-version mistake. `uci show`
# reads the CONFIG, and the config was there; it was fw4 that discarded the sections for an
# invalid `src_ip`. The script printed "OK, the change is permanent" with ZERO rules live.
# The only source of truth is the generated nftables.
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
