# DESKTOP: Hyprland on Wayland, with LightDM as the greeter. In a Wayland session the keyboard and
# the monitors are HYPRLAND config, not the system's xkb: docs/notes/desktop/desktop.md
{ pkgs, ... }:

{
  services.xserver.enable = true; # it enables LightDM (an X11 greeter) plus Xwayland
  services.xserver.displayManager.lightdm.enable = true;
  programs.hyprland.enable = true;

  # AUTOLOGIN, and it is not laziness: Sunshine captures a LIVE session, so with nobody logged in
  # there is nothing to stream. The security trade and the mitigation are in the notes.
  services.displayManager.autoLogin = {
    enable = true;
    user = "v1cferr";
  };
  services.displayManager.defaultSession = "hyprland";
  # The system's xkb covers only the greeter (LightDM/X11) and Xwayland apps.
  services.xserver.xkb = {
    layout = "br"; # the "br" default variant is ABNT2
    variant = "";
  };
  # Electron/Chromium apps run natively on Wayland instead of Xwayland.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # THE PORTALS. gtk serves org.freedesktop.appearance (dark mode in Electron); wlr implements
  # Screenshot, which portal-hyprland declares and then refuses. See docs/notes/desktop/desktop.md
  xdg.portal.extraPortals = [
    pkgs.xdg-desktop-portal-gtk
    pkgs.xdg-desktop-portal-wlr
  ];
  # Explicit routing: Screenshot to wlr, and the rest follows the default.
  xdg.portal.config.common = {
    default = [
      "hyprland"
      "gtk"
    ];
    "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
  };

  # KEYRING (org.freedesktop.secrets). MIND THE AUTOLOGIN: PAM never types a password, so the
  # "Login" keyring has an EMPTY one (state, rule 6). The trade is in the notes.
  services.gnome.gnome-keyring.enable = true;
  # Only for an INTERACTIVE login (a rescue path); inert under autologin.
  security.pam.services.lightdm.enableGnomeKeyring = true;
  programs.seahorse.enable = true; # the "Passwords and Keys" GUI, to manage/change the keyring's password

  # hyprlock's PAM. WITHOUT this it does not unlock and it LOCKS YOU OUT. The package and config
  # are the user's (home/desktop/lockscreen.nix); {} inherits the default login stack.
  security.pam.services.hyprlock = { };
}
