# Hyprland plus Wayland plus the user's appearance/session.
{ ... }:

{
  imports = [
    ./palette.nix # the SINGLE SOURCE of colors (my.theme.name); it generates the data for Quickshell/Hyprland
    ./stylix.nix # Stylix APPLIES that palette to the apps it has targets for (GTK, kitty, bat...)
    ./monitors.nix # the SINGLE SOURCE of the connectors (my.monitors); it generates the data for Quickshell/Hyprland
    ./keyboard.nix # the keyboard layout from the system (my.keyboard), as data for Hyprland
    ./weather.nix # the SINGLE SOURCE of the coordinates plus the WMO -> pt-BR table (my.weather)
    ./calendar # the HOLIDAY REGISTRY (sourced, verified) expanded into the calendar's data
    ./glance-feed # the network cache (SQLite) behind the bar's weather, the band and the lock screen
    ./autostart.nix # the PANEL of what opens at login (my.autostart): Discord/Spotifast
    ./polkit-agent.nix # the password dialog for a graphical app that needs authorization
    ./hypr.nix # ~/.config/hypr/hyprland.lua (ABNT2 plus monitors plus keybinds)
    ./hyprglass.nix # the Liquid Glass plugin, built for the session's Hyprland; off until my.hypr.hyprglass.enable
    ./clipboard-push.nix # the clipboard's image/file to a host over scp, its path left in the clipboard
    ./vicinae # the launcher (SUPER+Q) plus command palette, themed from the palette
    ./cheatsheet.nix # SUPER+H: the keybind list in Vicinae, GENERATED from keybinds.lua at runtime
    ./wallpaper.nix # hyprpaper: a random DARK photo per monitor, one pool per orientation
    ./hyprsunset.nix # the blue light filter (a systemd service plus profiles by time of day)
    ./quickshell.nix # the shell/bar/OSD/media plus NOTIFICATIONS in QML; hot-reload through mkOutOfStoreSymlink
    ./theme.nix # dark mode (prefer-dark), icons, cursor, and Qt through the recolored Kvantum
    ./xdg.nix # the default browser (Zen) through xdg.mimeApps plus $BROWSER
  ];
}
