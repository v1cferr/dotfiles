# Hyprland plus Wayland plus the user's appearance/session.
{ ... }:

{
  imports = [
    ./palette.nix # the SINGLE SOURCE of colors (my.theme.name); it generates the data for Quickshell/Hyprland
    ./monitors.nix # the SINGLE SOURCE of the connectors (my.monitors); it generates the data for Quickshell/Hyprland
    ./autostart.nix # the PANEL of what opens at login (my.autostart): Discord/Spotify
    ./polkit-agent.nix # the password dialog for a graphical app that needs authorization
    ./hypr.nix # ~/.config/hypr/hyprland.conf (ABNT2 plus monitors plus keybinds)
    ./clipboard.nix # cliphist (the history) plus rofi (a picker with an image/type preview); Tokyo Night
    ./launcher.nix # the app launcher (rofi drun: icons plus recency plus Tokyo Night)
    ./cheatsheet.nix # SUPER+H: the keybind list in rofi, GENERATED from keybinds.lua at runtime
    ./wallpaper.nix # hyprpaper: the desktop wallpaper (nixos-artwork; a dark main one plus moonscape on the TV)
    ./hyprsunset.nix # the blue light filter (a systemd service plus profiles by time of day)
    ./lockscreen.nix # hyprlock (the lock screen) plus hypridle (idle: dim plus lock)
    ./quickshell.nix # the shell/bar/OSD/media plus NOTIFICATIONS in QML; hot-reload through mkOutOfStoreSymlink
    ./theme.nix # dark mode (the prefer-dark color-scheme plus GTK Adwaita-dark)
    ./xdg.nix # the default browser (Zen) through xdg.mimeApps plus $BROWSER
  ];
}
