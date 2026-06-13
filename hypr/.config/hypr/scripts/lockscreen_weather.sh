#!/usr/bin/env bash
# ============================================================================
#  Temperatura/condição atual para a tela de bloqueio (hyprlock)
# ----------------------------------------------------------------------------
#  Aparece INSTANTÂNEO: sempre imprime o cache na hora e, se ele estiver
#  velho/ausente, dispara a atualização em segundo plano (nunca bloqueia o
#  hyprlock). Só mostra "carregando" no primeiríssimo uso (sem cache ainda).
#
#  Fonte primária: página de clima do MSN (a que o v1cferr confia), raspando
#  o JSON embutido. Fallback: o weather.sh do waybar (multi-API).
#
#  Saída: uma linha tipo "  16°C · Nublado"
# ============================================================================
set -u

# São Carlos/SP (URL percent-encoded para evitar problemas com acentos)
MSN_URL='https://www.msn.com/pt-br/clima/forecast/in-S%C3%A3o-Carlos,S%C3%A3o-Paulo'
CACHE="/tmp/lockscreen_weather.txt"
LOCK="/tmp/.lockscreen_weather.lock"
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

# Trabalho pesado (rede): roda em segundo plano e grava o cache.
refresh() {
    local hour is_day html temp cap icon txt
    hour=$(date +%H); is_day=1
    (( 10#${hour} < 6 || 10#${hour} >= 18 )) && is_day=0

    # 1) MSN — valores ATUAIS em currentTemperature/shortCap (temp/cap são da previsão)
    html=$(curl -s --max-time 8 -A "Mozilla/5.0 (X11; Linux x86_64)" "${MSN_URL}" 2>/dev/null)
    temp=$(grep -oP '"currentTemperature":"\K-?[0-9]+' <<<"${html}" | head -1)
    cap=$(grep -oP '"shortCap":"\K[^"]+'              <<<"${html}" | head -1)
    [[ -z ${temp} ]] && temp=$(grep -oP '"temp":\K-?[0-9]+' <<<"${html}" | head -1)
    [[ -z ${cap}  ]] && cap=$(grep -oP '"cap":"\K[^"]+'      <<<"${html}" | head -1)

    if [[ -n ${temp} ]]; then
        icon=$(icon_for "${cap:-}" "${is_day}")
        if [[ -n ${cap} ]]; then printf '%s  %s°C · %s\n' "${icon}" "${temp}" "${cap}" > "${CACHE}"
        else                     printf '%s  %s°C\n' "${icon}" "${temp}" > "${CACHE}"; fi
        return 0
    fi

    # 2) Fallback: weather.sh do waybar (JSON do waybar)
    if [[ -x ${WEATHER_SH} ]]; then
        txt=$("${WEATHER_SH}" 2>/dev/null | jq -r '.text // empty' 2>/dev/null)
        [[ -n ${txt} ]] && { printf '%s\n' "${txt}" > "${CACHE}"; return 0; }
    fi
    return 1
}

# Dispara refresh em background se o cache estiver velho/ausente (mkdir = lock).
need=0
if [[ ! -f ${CACHE} ]]; then
    need=1
else
    age=$(( $(date +%s) - $(stat -c %Y "${CACHE}") ))
    (( age >= TTL )) && need=1
fi
if (( need )); then
    if mkdir "${LOCK}" 2>/dev/null; then
        ( refresh; rmdir "${LOCK}" 2>/dev/null ) >/dev/null 2>&1 &
        disown
    fi
fi

# Resposta IMEDIATA: cache (mesmo velho) ou placeholder de carregando.
if [[ -s ${CACHE} ]]; then
    cat "${CACHE}"
else
    echo "  carregando…"
fi
