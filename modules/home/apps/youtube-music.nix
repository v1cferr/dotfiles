# Pear Desktop: the YouTube Music client, seen by the shell through its own MPRIS player.
# Why unstable and why no wrapper: docs/notes/apps/pear-desktop.md
{ pkgs, ... }:

{
  home.packages = [ pkgs.unstable.pear-desktop ]; # stable lags a release (3.11 against 3.12)
}
