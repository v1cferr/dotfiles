# `session-lock` for a host with NO lock of its own: it hands the screen to GDM's greeter.
# It is NOT a lock, the session stays reachable: docs/decisions/0018-a-shared-laptop.md
{ pkgs, ... }:

let
  inherit (pkgs) glib writeShellApplication;
in
{
  home.packages = [
    # GDM opens a greeter on a new VT, so the other person can log in; mine keeps running on its
    # own VT, and switching back to it asks for no password.
    (writeShellApplication {
      name = "session-lock";
      runtimeInputs = [ glib ];
      text = ''
        gdbus call --system --dest org.gnome.DisplayManager \
          --object-path /org/gnome/DisplayManager/LocalDisplayFactory \
          --method org.gnome.DisplayManager.LocalDisplayFactory.CreateTransientDisplay >/dev/null
      '';
    })
  ];
}
