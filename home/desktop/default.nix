# Hyprland + Wayland + aparência/sessão do usuário.
{ ... }:

{
  imports = [
    ./palette.nix # FONTE ÚNICA de cores (my.theme.name); gera os dados p/ Quickshell/Hyprland
    ./hypr.nix # ~/.config/hypr/hyprland.conf (ABNT2 + monitores + keybinds)
    ./clipboard.nix # cliphist (histórico) + rofi (picker c/ preview img/tipo); Tokyo Night
    ./launcher.nix # launcher de apps (rofi drun: ícones + recência + Tokyo Night)
    ./hyprsunset.nix # filtro de luz azul (serviço systemd + perfis por horário)
    ./lockscreen.nix # hyprlock (tela de bloqueio) + hypridle (idle: dim + lock)
    ./quickshell.nix # shell/bar/OSD/mídia + NOTIFICAÇÕES em QML; hot-reload via mkOutOfStoreSymlink
    ./theme.nix # dark mode (color-scheme prefer-dark + GTK Adwaita-dark)
    ./xdg.nix # browser default (Zen) via xdg.mimeApps + $BROWSER
  ];
}
