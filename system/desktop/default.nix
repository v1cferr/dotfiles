# The graphical environment (system level).
{ ... }:

{
  imports = [
    ./monitors.nix # the SINGLE SOURCE of the connectors (my.monitors), read by system/ and by home/ (osConfig)
    ./desktop.nix # LightDM, Hyprland, xkb, the portal (dark mode), gnome-keyring
  ];
}
