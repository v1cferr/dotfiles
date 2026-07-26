# Hyprland + Wayland + aparência/sessão do usuário.
{ ... }:

{
  imports = [
    ./hypr.nix # ~/.config/hypr/hyprland.conf (ABNT2 + monitores + keybinds)
    ./hyprsunset.nix # filtro de luz azul (serviço systemd + perfis por horário)
    ./lockscreen.nix # hyprlock (tela de bloqueio) + hypridle (idle: dim + lock)
    ./quickshell.nix # shell/bar/OSD/mídia + NOTIFICAÇÕES em QML; hot-reload via mkOutOfStoreSymlink
    ./theme.nix # dark mode (color-scheme prefer-dark + GTK Adwaita-dark)
    ./xdg.nix # browser default (Zen) via xdg.mimeApps + $BROWSER
  ];
}
