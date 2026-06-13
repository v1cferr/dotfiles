#!/usr/bin/env bash
# Seleciona um monitor no picker do flameshot 14 (binds 1/2 do submap
# "screenshot"). O picker só aceita clique de mouse
# (MonitorPreview::mousePressEvent), então sintetizamos o clique: move o
# cursor pro preview correspondente e manda mouse:272 pra janela.
# A numeração segue os rótulos do picker ("Monitor 1", "Monitor 2", ...).
#
# Depois do clique, o overlay de captura abre. Com suppress_event=fullscreen
# (ver window-rules.conf) ele é uma janela FLUTUANTE — não entra no modo
# fullscreen do Hyprland, então não esconde/restaura o tiling de baixo (era
# isso que causava o flash do wallpaper ao fechar). O custo: como flutuante
# ele respeita a área reservada da waybar e abre deslocado ~18px; por isso
# forçamos a geometria exata do monitor (movewindowpixel exact ignora o
# reserve) pra cobrir a tela inteira.
set -u

idx=${1:?uso: $0 <numero-do-monitor>}

n=$(hyprctl monitors -j | jq length)
[ "$idx" -ge 1 ] && [ "$idx" -le "$n" ] || exit 0

# geometria do PICKER (ainda é a única janela flameshot neste ponto)
geo=$(hyprctl clients -j | jq -r '
    map(select(.class == "flameshot")) | first |
    if . == null then empty else "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])" end')
[ -z "$geo" ] && exit 0
read -r px py pw ph <<<"$geo"

# previews lado a lado: clica no meio da fatia horizontal do monitor idx
cx=$((px + (pw * (2 * idx - 1)) / (2 * n)))
cy=$((py + ph * 60 / 100))
hyprctl dispatch movecursor "$cx" "$cy"
hyprctl dispatch sendshortcut ", mouse:272, class:flameshot"

# geometria LÓGICA do monitor escolhido (posição já é lógica; tamanho =
# modo físico / escala)
read -r mx my mw mh mcx mcy <<<"$(hyprctl monitors -j | jq -r --argjson i "$((idx - 1))" '
    .[$i] | "\(.x) \(.y) \(.width / .scale | round) \(.height / .scale | round) \(.x + (.width / .scale / 2) | round) \(.y + (.height / .scale / 2) | round)"')"

# espera o overlay aparecer (picker já fechou no clique) e força a cobertura
for _ in $(seq 1 20); do
    sleep 0.05
    hyprctl clients -j | jq -e 'any(.[]; .class == "flameshot")' >/dev/null || continue
    hyprctl dispatch resizewindowpixel exact "$mw" "$mh",class:flameshot
    hyprctl dispatch movewindowpixel exact "$mx" "$my",class:flameshot
    break
done

# deixa o cursor no centro do monitor escolhido pra seleção já começar lá
hyprctl dispatch movecursor "$mcx" "$mcy"
