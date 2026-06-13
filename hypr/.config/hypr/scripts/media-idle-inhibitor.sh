#!/usr/bin/env bash
# ============================================================================
#  Inibe o auto-lock/dpms (hypridle) enquanto houver mídia TOCANDO
# ----------------------------------------------------------------------------
#  Observa o status MPRIS via playerctl (mpv, navegadores, vlc, spotify…).
#  Enquanto QUALQUER player estiver "Playing", segura um inibidor de idle do
#  systemd — que o hypridle respeita (ignore_systemd_inhibit = false). Quando
#  tudo está pausado/parado/sem player, solta o inibidor e o hypridle volta a
#  contar normalmente (lock em 5 min de inatividade).
#
#  Sobe via exec-once no autostart. Detecção em ~3s (poll); irrelevante perto
#  do timeout de 5 min.
# ============================================================================
set -u

# Só uma instância (autostart + start manual não duplicam)
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/.media-idle-inhibitor.lock"
flock -n 9 || exit 0

INHIBIT_PID=""

is_playing() { playerctl -a status 2>/dev/null | grep -q '^Playing$'; }

hold() {
    [[ -n ${INHIBIT_PID} ]] && kill -0 "${INHIBIT_PID}" 2>/dev/null && return
    systemd-inhibit --what=idle --who="media-idle-inhibitor" \
        --why="reproduzindo mídia" --mode=block sleep infinity &
    INHIBIT_PID=$!
}

release() {
    [[ -n ${INHIBIT_PID} ]] || return
    kill "${INHIBIT_PID}" 2>/dev/null
    INHIBIT_PID=""
}

cleanup() { release; exit 0; }
trap cleanup TERM INT EXIT

while true; do
    if is_playing; then hold; else release; fi
    sleep 3
done
