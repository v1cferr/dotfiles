# HYDRA LAUNCHER, the user side (the package is pkgs/hydralauncher/package.nix, always upstream's latest).
# Why the scheme is declared here and not left to the app: docs/notes/apps/hydralauncher.md
{ pkgs, ... }:

{
  home.packages = [
    pkgs.hydralauncher # ./pkgs: the official AppImage, pinned to the sha512 upstream publishes
  ];

  # Merges with the associations from xdg.nix and media.nix. The login comes back through it.
  xdg.mimeApps.defaultApplications."x-scheme-handler/hydralauncher" = "hydralauncher.desktop";
}
