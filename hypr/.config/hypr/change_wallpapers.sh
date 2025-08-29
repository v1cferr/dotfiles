#!/usr/bin/env bash
WALLS=(/home/v1cferr/Pictures/Wallpapers/*.{jpg,png})
WALL="${WALLS[$RANDOM % ${#WALLS[@]}]}"
hyprctl hyprpaper preload "$WALL"
sleep 0.5
# usar wildcard ("" para aplicar a todos os displays) ou "DP-1,$WALL"
hyprctl hyprpaper wallpaper ",$WALL"
hyprctl hyprpaper unload unused
