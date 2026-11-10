# The graphical environment (system level).
{ ... }:

{
  imports = [
    ./monitors.nix # the SINGLE SOURCE of the connectors (my.monitors), read by modules/nixos/ and by modules/home/ (osConfig)
    ./keyboard.nix # the SSOT of the keyboard layout (my.keyboard): the TTY, the greeter and Hyprland
    ./fonts.nix # the SSOT of the UI font (my.fonts.ui) plus fontconfig plus the MS metrics
    ./spellcheck.nix # the SSOT of the spellcheck languages (my.spellcheck.languages) plus the hunspell dictionaries
    ./web-apps.nix # my.webApps (SSOT): sites lighter than their vendor app; Chrome installs its share
    ./desktop.nix # Hyprland, xkb, the portal (dark mode), gnome-keyring; the greeter is the host's
  ];
}
