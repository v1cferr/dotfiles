#!/usr/bin/env bash
# Seleciona um monitor no picker do flameshot 14 (binds 1/2 do submap
# "screenshot"). O picker só aceita clique de mouse
# (MonitorPreview::mousePressEvent), então sintetizamos o clique: move o
# cursor pro preview correspondente e manda mouse:272 pra janela.
# A numeração segue os rótulos do picker ("Monitor 1", "Monitor 2", ...).

idx=${1:?uso: $0 <numero-do-monitor>}

geo=$(hyprctl clients -j | jq -r '
    map(select(.class == "flameshot" and .fullscreen == 0)) | first |
    if . == null then empty else "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])" end')
[ -z "$geo" ] && exit 0
read -r x y w h <<<"$geo"

n=$(hyprctl monitors -j | jq length)
[ "$idx" -ge 1 ] && [ "$idx" -le "$n" ] || exit 0

# previews lado a lado: clica no meio da fatia horizontal do monitor idx
cx=$((x + (w * (2 * idx - 1)) / (2 * n)))
cy=$((y + h * 60 / 100))

hyprctl dispatch movecursor "$cx" "$cy"
hyprctl dispatch sendshortcut ", mouse:272, class:flameshot"

# deixa o cursor no centro do monitor escolhido pra seleção já começar lá
# (assume que a ordem dos previews segue a ordem de hyprctl monitors -j)
sleep 0.15
center=$(hyprctl monitors -j | jq -r --argjson i "$((idx - 1))" \
    '.[$i] | "\(.x + .width / 2 | floor) \(.y + .height / 2 | floor)"')
[ -n "$center" ] && hyprctl dispatch movecursor $center
