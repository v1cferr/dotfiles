# Ambiente gráfico (nível-sistema).
{ ... }:

{
  imports = [
    ./monitors.nix # FONTE ÚNICA dos conectores (my.monitors) — lido por system/ e por home/ (osConfig)
    ./desktop.nix # LightDM, Hyprland, xkb, portal (dark mode), gnome-keyring
  ];
}
