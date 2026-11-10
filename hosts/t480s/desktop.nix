# The t480s's greeter and its second desktop: GDM offering GNOME (cesar) and Hyprland (v1cferr).
# Why GDM and not the desk's LightDM: docs/decisions/0018-a-shared-laptop.md
{ ... }:

{
  # GDM, and NO autologin: two people share this machine. GNOME's screen lock is GDM's.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # GNOME turns Orca on, and Orca turns on the speech daemon audio.nix keeps off on purpose.
  services.orca.enable = false;
}
