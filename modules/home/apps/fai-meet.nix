# FAI MEET, the user side (the package is pkgs/fai-meet/package.nix): the FAI's meeting recorder.
# Why the scheme is declared here and not by the app: docs/notes/apps/fai-meet.md
{ pkgs, ... }:

{
  home.packages = [ pkgs.fai-meet ]; # the official AppImage, repackaged (./pkgs), unfree

  # Merges with the associations from xdg.nix and media.nix. The app's own xdg-mime call cannot
  # write the store-managed mimeapps.list, so without this the login comes back to nothing.
  xdg.mimeApps.defaultApplications."x-scheme-handler/fai-meet" = "fai-meet.desktop";
}
