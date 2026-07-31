# Hyprland + Wayland + aparência/sessão do usuário.
{ ... }:

{
  imports = [
    ./palette.nix # FONTE ÚNICA de cores (my.theme.name); gera os dados p/ Quickshell/Hyprland
    ./monitors.nix # FONTE ÚNICA dos conectores (my.monitors); gera os dados p/ Quickshell/Hyprland
    ./autostart.nix # PAINEL do que abre no login (my.autostart) — Discord/Spotify
    ./hypr.nix # ~/.config/hypr/hyprland.conf (ABNT2 + monitores + keybinds)
    ./clipboard.nix # cliphist (histórico) + rofi (picker c/ preview img/tipo); Tokyo Night
    ./launcher.nix # launcher de apps (rofi drun: ícones + recência + Tokyo Night)
    ./cheatsheet.nix # SUPER+H: lista de keybinds no rofi, GERADA do keybinds.lua em runtime
    ./wallpaper.nix # hyprpaper: wallpaper de desktop (nixos-artwork; principal dark + TV moonscape)
    ./hyprsunset.nix # filtro de luz azul (serviço systemd + perfis por horário)
    ./lockscreen.nix # hyprlock (tela de bloqueio) + hypridle (idle: dim + lock)
    ./quickshell.nix # shell/bar/OSD/mídia + NOTIFICAÇÕES em QML; hot-reload via mkOutOfStoreSymlink
    ./theme.nix # dark mode (color-scheme prefer-dark + GTK Adwaita-dark)
    ./xdg.nix # browser default (Zen) via xdg.mimeApps + $BROWSER
  ];
}
