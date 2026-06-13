#!/usr/bin/env bash
# ============================================================================
#  Frame atual do GIF da tela de bloqueio (monitor secundário do hyprlock)
# ----------------------------------------------------------------------------
#  O hyprlock não anima GIF nativamente. O background do monitor secundário
#  usa reload_time=0 + reload_cmd apontando para cá, e este script devolve o
#  frame correspondente ao instante atual.
#
#  Um GIF diferente é sorteado a cada lock novo E a cada 2.5 min dentro do
#  mesmo lock (ROTATE) — de ~/Pictures/Wallpapers/lockscreen-gifs/ (coleção
#  do CtorW/Hypr-live-paperlls — basta jogar mais .gif na pasta). Os frames
#  são extraídos sob demanda para o cache; enquanto a extração roda, devolve
#  um wallpaper estático.
# ============================================================================
set -u

GIFDIR="${HOME}/Pictures/Wallpapers/lockscreen-gifs"
FALLBACK="${HOME}/Pictures/Wallpapers/acoolrocket-dalle2-hokusai-non-prompt-landscape.png"
CACHE="${HOME}/.cache/hypr/lockgif"
CURRENT="${CACHE}/.current"     # GIF escolhido no momento
SESSION="${CACHE}/.session"     # marcador da sessão (pid+starttime do hyprlock)
PICKED="${CACHE}/.picked_at"    # epoch de quando o GIF atual foi escolhido
ROTATE=150                      # troca de GIF a cada 2.5 min no mesmo lock
FPS=10

mkdir -p "${CACHE}"

gifs=("${GIFDIR}"/*.gif)
if [[ ! -e ${gifs[0]} ]]; then
    echo "${FALLBACK}"
    exit 0
fi

# Identifica a sessão de lock pelo pid+starttime do hyprlock.
pid="$(pgrep -o -x hyprlock 2>/dev/null || true)"
sid="none"
[[ -n ${pid} ]] && sid="${pid}:$(awk '{print $22}' "/proc/${pid}/stat" 2>/dev/null)"

# Avança a fila quando: (a) é um lock novo, ou (b) já passaram ROTATE segundos
# desde que o GIF atual foi escolhido (troca periódica dentro do mesmo lock).
QUEUE="${CACHE}/.queue"
advance=0
if [[ ! -f ${SESSION} || "$(<"${SESSION}")" != "${sid}" ]]; then
    advance=1                                   # lock novo
elif [[ ! -f ${PICKED} || ! -f ${CURRENT} ]]; then
    advance=1                                   # sem estado -> escolhe agora
elif (( $(date +%s) - $(<"${PICKED}") >= ROTATE )); then
    advance=1                                   # passou o tempo de troca
fi

# Fila embaralhada (.queue): cada GIF aparece UMA vez antes de qualquer
# repetição; quando esvazia, reembaralha — sem deixar o último mostrado
# abrir o ciclo novo (repetição imediata na virada).
if (( advance )); then
    prev=""
    [[ -f ${CURRENT} ]] && prev="$(<"${CURRENT}")"
    pick=""
    while [[ -z ${pick} ]]; do
        if [[ ! -s ${QUEUE} ]]; then
            printf '%s\n' "${gifs[@]}" | shuf >"${QUEUE}"
            if (( ${#gifs[@]} > 1 )) && [[ "$(head -n1 "${QUEUE}")" == "${prev}" ]]; then
                { tail -n +2 "${QUEUE}"; head -n1 "${QUEUE}"; } >"${QUEUE}.tmp" \
                    && mv "${QUEUE}.tmp" "${QUEUE}"
            fi
        fi
        pick="$(head -n1 "${QUEUE}")"
        sed -i '1d' "${QUEUE}"
        [[ -f ${pick} ]] || pick=""   # GIF removido da pasta -> tenta o próximo
    done
    echo "${pick}" >"${CURRENT}"
    echo "${sid}" >"${SESSION}"
    date +%s >"${PICKED}"
fi

gif="$(<"${CURRENT}")"
if [[ ! -f ${gif} ]]; then
    echo "${FALLBACK}"
    exit 0
fi

name="$(basename "${gif}" .gif)"
fdir="${CACHE}/${name}"
stamp="${fdir}/.stamp"
cur="$(stat -c %Y "${gif}")"

# GIF novo ou alterado -> (re)extrai os frames em segundo plano. mkdir é
# atômico e serve de lock contra extrações concorrentes (o reload_cmd é
# chamado várias vezes por segundo).
if [[ ! -f ${stamp} || "$(<"${stamp}")" != "${cur}" ]]; then
    if mkdir "${CACHE}/.extracting-${name}" 2>/dev/null; then
        (
            tmp="${CACHE}/.tmp-${name}"
            rm -rf "${tmp}" && mkdir -p "${tmp}"
            if magick "${gif}" -coalesce "${tmp}/frame_%05d.png"; then
                echo "${cur}" >"${tmp}/.stamp"
                rm -rf "${fdir}"
                mv "${tmp}" "${fdir}"
            fi
            rm -rf "${tmp}" "${CACHE}/.extracting-${name}"
        ) >/dev/null 2>&1 &
        disown
    fi
    echo "${FALLBACK}"
    exit 0
fi

frames=("${fdir}"/frame_*.png)
n=${#frames[@]}
if (( n == 0 )) || [[ ! -e ${frames[0]} ]]; then
    echo "${FALLBACK}"
    exit 0
fi

# Frame em função do relógio, assim a animação corre em tempo real mesmo
# que o hyprlock chame o script em ritmo irregular. Divide ANTES de tomar
# o módulo: epoch_ns * FPS estouraria 64 bits.
idx=$(( ($(date +%s%N) / (1000000000 / FPS)) % n ))
echo "${frames[idx]}"
