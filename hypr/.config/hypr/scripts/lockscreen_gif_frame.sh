#!/usr/bin/env bash
# ============================================================================
#  Frame atual do GIF da tela de bloqueio (monitor secundário do hyprlock)
# ----------------------------------------------------------------------------
#  O hyprlock não anima GIF nativamente. O truque: o background do monitor
#  secundário usa reload_time=0 + reload_cmd apontando para este script, que
#  devolve o caminho do frame correspondente ao instante atual.
#
#  Na primeira vez (ou quando o GIF muda), os frames são extraídos para o
#  cache em segundo plano; enquanto isso devolve um wallpaper estático
#  (o hyprlock não decodifica .gif, só os frames .png do cache).
#
#  Para trocar a animação: substitua ~/Pictures/Wallpapers/lockscreen.gif
#  por qualquer GIF. A extração é refeita sozinha no próximo lock.
# ============================================================================
set -u

GIF="${HOME}/Pictures/Wallpapers/lockscreen.gif"
FALLBACK="${HOME}/Pictures/Wallpapers/acoolrocket-dalle2-hokusai-non-prompt-landscape.png"
CACHE="${HOME}/.cache/hypr/lockgif"
STAMP="${CACHE}/.stamp"
FPS=10

# Sem GIF -> wallpaper estático e pronto.
if [[ ! -f ${GIF} ]]; then
    echo "${FALLBACK}"
    exit 0
fi

# GIF novo ou alterado -> (re)extrai os frames em segundo plano.
# mkdir é atômico e serve de lock contra extrações concorrentes
# (o reload_cmd é chamado várias vezes por segundo).
cur="$(stat -c %Y "${GIF}")"
if [[ ! -f ${STAMP} || "$(<"${STAMP}")" != "${cur}" ]]; then
    mkdir -p "${CACHE}"
    if mkdir "${CACHE}/.extracting" 2>/dev/null; then
        (
            tmp="${CACHE}/.tmp"
            rm -rf "${tmp}" && mkdir -p "${tmp}"
            if magick "${GIF}" -coalesce "${tmp}/frame_%05d.png"; then
                rm -f "${CACHE}"/frame_*.png
                mv "${tmp}"/frame_*.png "${CACHE}/"
                echo "${cur}" >"${STAMP}"
            fi
            rm -rf "${tmp}" "${CACHE}/.extracting"
        ) >/dev/null 2>&1 &
        disown
    fi
    echo "${FALLBACK}"
    exit 0
fi

frames=("${CACHE}"/frame_*.png)
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
