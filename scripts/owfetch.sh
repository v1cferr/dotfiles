#!/bin/sh
# owfetch — resumo do sistema para OpenWrt, no espírito do fastfetch.
#
# POR QUE UM SCRIPT E NÃO O FASTFETCH: o /overlay deste roteador tem ~1.4 MB
# livres de 6.1 MB. O fastfetch pesa 1-2 MB e o neofetch ainda arrastaria o bash
# junto — qualquer um dos dois enche a flash, e roteador com flash cheia não
# grava nem config. Isto aqui usa só BusyBox: custo zero de instalação.
#
# ash puro, sem bashismo: nada de arrays, [[ ]] ou ${var^^}. A ORDEM dos campos
# espelha home/shell/fastfetch.nix (title, separator, os, host, kernel, uptime,
# cpu, memory, disk, localip, colors) pra os dois se lerem igual.

# ESC REAL, e não a sequência "\033" literal: as cores são passadas como ARGUMENTO
# (%s) e não dentro do format string do printf. Format com variável dentro é o
# SC2059 do shellcheck — e o motivo dele existir é real: um valor com % viraria
# diretiva de formatação. Como %s não interpreta escapes, o \033 precisa já vir
# expandido daqui.
ESC=$(printf '\033')
C_LOGO="${ESC}[1;36m" # ciano: o logo
C_LBL="${ESC}[1;34m"  # azul:  rótulos
C_TTL="${ESC}[1;37m"  # branco: título
C_DIM="${ESC}[0;90m"  # cinza: separador
C_OFF="${ESC}[0m"

# ── coleta ────────────────────────────────────────────────────────────────────
# shellcheck disable=SC1091  # só existe no roteador; não há como o linter segui-lo
[ -r /etc/openwrt_release ] && . /etc/openwrt_release
REL="${DISTRIB_RELEASE:-?}"
REV="${DISTRIB_REVISION:-}"
TGT="${DISTRIB_TARGET:-?}"
ARCH="${DISTRIB_ARCH:-$(uname -m)}"

MODEL=$(cat /tmp/sysinfo/model 2>/dev/null || echo "desconhecido")
KERN=$(uname -r)
MACH=$(uname -m)

# uptime: /proc/uptime dá segundos com fração; só a parte inteira interessa
UPS=$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)
UPD=$((UPS / 86400))
UPH=$(((UPS % 86400) / 3600))
UPM=$(((UPS % 3600) / 60))
if [ "$UPD" -gt 0 ]; then
	UPTIME="${UPD}d ${UPH}h ${UPM}min"
elif [ "$UPH" -gt 0 ]; then
	UPTIME="${UPH}h ${UPM}min"
else
	UPTIME="${UPM}min"
fi

NPROC=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo '?')
# ARM não expõe "model name" em /proc/cpuinfo — o nome útil vem do DISTRIB_ARCH
# (ex.: aarch64_cortex-a53). Fallback pro model name quando existir (x86).
CPUN=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ *//')
# `aarch64_cortex-a53` → `Cortex-A53`. Caixa alta crua ficava gritando na tela.
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
[ -z "$WAN" ] && WAN="sem link"

LEASES=$(wc -l < /tmp/dhcp.leases 2>/dev/null || echo 0)

# ── saída ─────────────────────────────────────────────────────────────────────
linha() { printf '  %s%-10s%s %s\n' "$C_LBL" "$1" "$C_OFF" "$2"; }

printf '\n'
printf '%s' "$C_LOGO"
cat <<'ART'
   _______                     ________        __
  |       |.-----.-----.-----.|  |  |  |.----.|  |_
  |   -   ||  _  |  -__|     ||  |  |  ||   _||   _|
  |_______||   __|_____|__|__||________||__|  |____|
           |__|
ART
printf '%s\n' "$C_OFF"

printf '  %s%s@%s%s\n' "$C_TTL" "$(id -un)" "$(uname -n)" "$C_OFF"
printf '  %s%s%s\n' "$C_DIM" "──────────────────────────────────────────────" "$C_OFF"

linha "OS"       "OpenWrt ${REL}${REV:+ ($REV)}"
linha "Host"     "$MODEL"
linha "Kernel"   "Linux ${KERN} · ${MACH}"
linha "Target"   "$TGT"
linha "Uptime"   "$UPTIME"
linha "CPU"      "${CPUN} (${NPROC} núcleos)"
linha "Load"     "$LOAD"
linha "RAM"      "$MEM"
linha "Flash"    "$FLASH"
linha "LAN"      "${LAN:-n/d}"
linha "WAN"      "$WAN"
linha "Clientes" "${LEASES} no DHCP"

# faixa de cores, como o módulo `colors` do fastfetch
printf "\n  "
for c in 0 1 2 3 4 5 6 7; do printf "\033[4%sm   \033[0m" "$c"; done
printf "\n  "
for c in 0 1 2 3 4 5 6 7; do printf "\033[10%sm   \033[0m" "$c"; done
printf "\n\n"
