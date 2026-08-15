#!/bin/sh
# owfetch: a system summary for OpenWrt, in fastfetch's spirit.
#
# WHY A SCRIPT AND NOT FASTFETCH: this router's /overlay has ~1.4 MB free out of 6.1 MB.
# fastfetch weighs 1-2 MB and neofetch would drag bash along on top of that, so either one fills
# the flash, and a router with full flash cannot even write its config. This uses only BusyBox:
# zero installation cost.
#
# Pure ash, no bashisms: no arrays, no [[ ]], no ${var^^}. The field ORDER mirrors
# home/shell/fastfetch.nix (title, separator, os, host, kernel, uptime, cpu, memory, disk,
# localip, colors) so the two read alike.

# A REAL ESC, and not the literal "\033" sequence: the colors are passed as an ARGUMENT (%s) and
# not inside printf's format string. A format with a variable inside is shellcheck's SC2059, and
# its reason for existing is real: a value containing % would become a formatting directive.
# Since %s does not interpret escapes, the \033 has to arrive already expanded from here.
ESC=$(printf '\033')
C_LBL="${ESC}[1;34m" # blue:  the labels
C_TTL="${ESC}[1;37m" # white: the title
C_DIM="${ESC}[0;90m" # gray:  the separator
C_OFF="${ESC}[0m"

# ── collecting ────────────────────────────────────────────────────────────────
# shellcheck disable=SC1091  # it only exists on the router; the linter has no way to follow it
[ -r /etc/openwrt_release ] && . /etc/openwrt_release
REL="${DISTRIB_RELEASE:-?}"
REV="${DISTRIB_REVISION:-}"
TGT="${DISTRIB_TARGET:-?}"
ARCH="${DISTRIB_ARCH:-$(uname -m)}"

MODEL=$(cat /tmp/sysinfo/model 2>/dev/null || echo "unknown")
KERN=$(uname -r)
MACH=$(uname -m)

# uptime: /proc/uptime gives seconds with a fraction; only the integer part matters
UPS=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)
UPD=$((UPS / 86400))
UPH=$(((UPS % 86400) / 3600))
UPM=$(((UPS % 3600) / 60))
if [ "$UPD" -gt 0 ]; then
	UPTIME="${UPD}d ${UPH}h ${UPM}m"
elif [ "$UPH" -gt 0 ]; then
	UPTIME="${UPH}h ${UPM}m"
else
	UPTIME="${UPM}m"
fi

NPROC=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo '?')
# ARM does not expose "model name" in /proc/cpuinfo, so the useful name comes from DISTRIB_ARCH
# (aarch64_cortex-a53, say). It falls back to the model name when there is one (x86).
CPUN=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ *//')
# `aarch64_cortex-a53` becomes `Cortex-A53`. Raw uppercase was shouting on the screen.
[ -z "$CPUN" ] && CPUN=$(echo "$ARCH" | cut -d_ -f2- | sed 's/cortex-a/Cortex-A/')
[ -z "$CPUN" ] && CPUN="$MACH"

LOAD=$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)

MEM=$(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{
	u=t-a; printf "%.0f MiB / %.0f MiB (%d%%)", u/1024, t/1024, (u*100)/t
}' /proc/meminfo 2>/dev/null)

FLASH=$(df -h /overlay 2>/dev/null | awk 'NR==2{printf "%s / %s (%s)", $3, $2, $5}')

LAN=$(ip -4 -o addr show br-lan 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)
WAN=$(ip -4 -o addr show pppoe-wan 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)
[ -z "$WAN" ] && WAN=$(ip -4 -o addr show wan 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)
[ -z "$WAN" ] && WAN="no link"

LEASES=$(wc -l < /tmp/dhcp.leases 2>/dev/null || echo 0)

# ── the output ────────────────────────────────────────────────────────────────
line() { printf '  %s%-10s%s %s\n' "$C_LBL" "$1" "$C_OFF" "$2"; }

# NO ASCII logo on purpose: OpenWrt's /etc/banner already draws the same art at login, and the
# fetch came right below it, so two identical logos on the same screen.
printf '\n'
printf '  %s%s@%s%s\n' "$C_TTL" "$(id -un)" "$(uname -n)" "$C_OFF"
printf '  %s%s%s\n' "$C_DIM" "──────────────────────────────────────────────" "$C_OFF"

line "OS"       "OpenWrt ${REL}${REV:+ ($REV)}"
line "Host"     "$MODEL"
line "Kernel"   "Linux ${KERN} · ${MACH}"
line "Target"   "$TGT"
line "Uptime"   "$UPTIME"
line "CPU"      "${CPUN} (${NPROC} cores)"
line "Load"     "$LOAD"
line "RAM"      "$MEM"
line "Flash"    "$FLASH"
line "LAN"      "${LAN:-n/a}"
line "WAN"      "$WAN"
line "Clients"  "${LEASES} on DHCP"

# the color strip, like fastfetch's `colors` module
printf "\n  "
for c in 0 1 2 3 4 5 6 7; do printf "\033[4%sm   \033[0m" "$c"; done
printf "\n  "
for c in 0 1 2 3 4 5 6 7; do printf "\033[10%sm   \033[0m" "$c"; done
printf "\n\n"
