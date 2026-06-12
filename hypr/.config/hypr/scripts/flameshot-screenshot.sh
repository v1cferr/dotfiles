#!/usr/bin/env bash
# Abre o flameshot gui e cuida do submap "screenshot" do Hyprland.
# O bind SUPER+SHIFT+S entra no submap (1/2 escolhe monitor, Esc cancela);
# este watcher reseta o submap sozinho quando o picker some — clique no
# mouse, Esc dentro do flameshot ou timeout — pra não deixar as teclas
# 1/2 sequestradas depois que o seletor fecha.

flameshot gui &

picker_open() {
    hyprctl clients -j | jq -e \
        'map(select(.class == "flameshot" and .fullscreen == 0)) | length > 0' \
        >/dev/null
}

(
    # espera o picker aparecer (até 3s)...
    for _ in $(seq 1 15); do
        sleep 0.2
        picker_open && break
    done
    # ...e reseta quando ele fechar ou virar overlay de captura (até 60s)
    for _ in $(seq 1 300); do
        picker_open || break
        sleep 0.2
    done
    hyprctl dispatch submap reset
) >/dev/null 2>&1 &
