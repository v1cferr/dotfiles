#!/usr/bin/env bash
# ============================================================================
#  Temperatura/condição atual para a tela de bloqueio (hyprlock)
# ----------------------------------------------------------------------------
#  Fonte primária: página de clima do MSN (a que o v1cferr confia), raspando
#  o JSON embutido na página. Fallback: o weather.sh do waybar (multi-API).
#  Cache de 10 min para não martelar o MSN a cada lock.
#
#  Saída: uma linha tipo "  16°C · Nublado"
# ============================================================================
set -u

# São Carlos/SP (URL percent-encoded para evitar problemas com acentos)
MSN_URL='https://www.msn.com/pt-br/clima/forecast/in-S%C3%A3o-Carlos,S%C3%A3o-Paulo'
CACHE="/tmp/lockscreen_weather.txt"
TTL=600
WEATHER_SH="${HOME}/.config/waybar/scripts/weather.sh"

# Condição em PT -> ícone Nerd Font ($2 = is_day: 1 dia, 0 noite)
icon_for() {
    local c="${1,,}" d="$2" i="󰖐"
    case "${c}" in
        *ensolarad*|*limpo*|*sol*|*claro*)        [[ ${d} == 0 ]] && i="" || i="" ;;
        *parcial*|*poucas\ nuvens*)               [[ ${d} == 0 ]] && i="" || i="" ;;
        *nublad*|*encobert*|*nuvens*|*nuvem*)     i="" ;;
        *neblina*|*névoa*|*nevoeiro*|*bruma*)     i="" ;;
        *trovoad*|*tempestade*|*raio*|*relâmpag*) i="" ;;
        *chuv*|*garoa*|*chuvisco*|*pancada*|*aguaceiro*) i="" ;;
        *neve*|*gelo*|*granizo*)                  i="" ;;
    esac
    printf '%s' "${i}"
}

emit() { printf '%s\n' "$1" > "${CACHE}"; printf '%s\n' "$1"; }

# Cache ainda fresco?
if [[ -f ${CACHE} ]]; then
    age=$(( $(date +%s) - $(stat -c %Y "${CACHE}") ))
    (( age < TTL )) && { cat "${CACHE}"; exit 0; }
fi

hour=$(date +%H); is_day=1
(( 10#${hour} < 6 || 10#${hour} >= 18 )) && is_day=0

# --- 1) MSN (raspagem do JSON embutido) ---
#  O bloco "currentCondition" traz os valores ATUAIS em "currentTemperature"
#  e "shortCap" (os campos "temp"/"cap" da página são da previsão do dia).
html=$(curl -s --max-time 8 -A "Mozilla/5.0 (X11; Linux x86_64)" "${MSN_URL}" 2>/dev/null)
temp=$(grep -oP '"currentTemperature":"\K-?[0-9]+' <<<"${html}" | head -1)
cap=$(grep -oP '"shortCap":"\K[^"]+'              <<<"${html}" | head -1)
# Fallback de parsing: campos de nível de página
[[ -z ${temp} ]] && temp=$(grep -oP '"temp":\K-?[0-9]+' <<<"${html}" | head -1)
[[ -z ${cap}  ]] && cap=$(grep -oP '"cap":"\K[^"]+'      <<<"${html}" | head -1)

if [[ -n ${temp} ]]; then
    icon=$(icon_for "${cap:-}" "${is_day}")
    if [[ -n ${cap} ]]; then emit "${icon}  ${temp}°C · ${cap}"; else emit "${icon}  ${temp}°C"; fi
    exit 0
fi

# --- 2) Fallback: weather.sh do waybar (retorna JSON do waybar) ---
if [[ -x ${WEATHER_SH} ]]; then
    txt=$("${WEATHER_SH}" 2>/dev/null | jq -r '.text // empty' 2>/dev/null)
    [[ -n ${txt} ]] && { emit "${txt}"; exit 0; }
fi

# --- 3) Último recurso: cache velho ou placeholder ---
[[ -f ${CACHE} ]] && { cat "${CACHE}"; exit 0; }
echo "󰖐  --°C"
