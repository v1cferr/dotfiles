# LIGHTDM WITH AUTOLOGIN: the greeter of a machine that must hold a live session with nobody at it.
# A ROLE, imported by the host. The security trade and its mitigation: docs/notes/desktop/desktop.md
{ ... }:

{
  services.xserver.displayManager.lightdm.enable = true;

  # AUTOLOGIN, and it is not laziness: Sunshine captures a LIVE session, so with nobody logged in
  # there is nothing to stream.
  services.displayManager.autoLogin = {
    enable = true;
    user = "v1cferr";
  };

  # Only for an INTERACTIVE login (a rescue path); inert under autologin.
  security.pam.services.lightdm.enableGnomeKeyring = true;
}
