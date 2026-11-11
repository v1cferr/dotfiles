# The t480s's greeter and what it offers: GNOME, the shared Hyprland, and each person's own session.
# Why GDM and not the desk's LightDM: docs/decisions/0018-a-shared-laptop.md
{ ... }:

{
  imports = [
    ../../modules/nixos/desktop/user-session.nix # a greeter entry that runs ~/.config/session/start
  ];

  # GDM, and NO autologin: two people share this machine. GNOME's screen lock is GDM's.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # GNOME turns Orca on, and Orca turns on the speech daemon audio.nix keeps off on purpose.
  services.orca.enable = false;
}
