#!/usr/bin/env bash
# Dispara o menu de contexto NATIVO de um SNI que não expõe DBusMenu (ícones
# do xembedsniproxy: wine/Battle.net, pamac). O Quickshell não chama o método
# ContextMenu() do SNI (o display() dele só serve DBusMenu), então fazemos na
# mão: acha o serviço no bus cujo Id bate com o argumento e chama ContextMenu
# na posição atual do cursor. O xembedsniproxy repassa o clique pro X11 e o
# app (wine/GTK) desenha o próprio menu ali.
#
# Uso: tray-native-menu.sh <SNI-Id>
set -u

target_id="${1:-}"
[ -z "$target_id" ] && exit 2

# posição global do cursor ("x, y")
pos="$(hyprctl cursorpos 2>/dev/null)"
gx="${pos%%,*}"
gy="${pos##*,}"
gx="${gx//[[:space:]]/}"
gy="${gy//[[:space:]]/}"
[[ "$gx" =~ ^[0-9]+$ ]] || gx=0
[[ "$gy" =~ ^[0-9]+$ ]] || gy=0

items="$(busctl --user get-property org.kde.StatusNotifierWatcher \
    /StatusNotifierWatcher org.kde.StatusNotifierWatcher \
    RegisteredStatusNotifierItems 2>/dev/null)"

for tok in $items; do
    # entradas vêm entre aspas ("svc/path"); "as" e a contagem não têm aspas
    entry="${tok//\"/}"
    [ "$entry" = "$tok" ] && continue
    svc="${entry%%/*}"
    path="/${entry#*/}"

    id="$(busctl --user get-property "$svc" "$path" \
        org.kde.StatusNotifierItem Id 2>/dev/null)"
    id="${id#s \"}"
    id="${id%\"}"

    if [ "$id" = "$target_id" ]; then
        busctl --user call "$svc" "$path" \
            org.kde.StatusNotifierItem ContextMenu ii "$gx" "$gy" 2>/dev/null
        exit $?
    fi
done

exit 1
