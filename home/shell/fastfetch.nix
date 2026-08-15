# fastfetch: a system summary (`programs.fastfetch` installs the package AND writes
# ~/.config/fastfetch/config.jsonc; app plus config in home, rule 4).
#
# Why there is a config instead of only the package: in VS Code's integrated terminal the
# "Terminal:" line came out with Electron's ENTIRE command line (~1.5 KB of
# `--standard-schemes=...`, `--field-trial-handle=...`), blowing up the layout. The cause:
# fastfetch builds the terminal's name from the basename of the parent process' COMPLETE
# /proc/<pid>/cmdline, and VS Code's pty host has `--user-data-dir=.../Code` in the middle, so the
# basename takes everything after the last "/" ("Code --standard-schemes…").
# The fix: formatting the terminal module with {process-name} (which comes from comm, always
# clean) instead of the default {pretty-name}. That gives "code 1.131.0", "kitty 0.44.1" and so
# on.
#
# The module list is fastfetch's DEFAULT STRUCTURE (`fastfetch --print-structure`, lowercased)
# repeated in full: that is the only way to change the format of ONE module, since there is no
# per-module override and whoever declares `modules` declares them all. Modules that do not apply
# to this machine (battery/poweradapter/host/de) disappear on their own; they stay here for
# portability.
{ pkgs, ... }:

{
  programs.fastfetch = {
    enable = true;
    package = pkgs.unstable.fastfetch; # bleeding-edge: new hardware/versions

    settings.modules = [
      "title"
      "separator"
      "os"
      "host"
      "kernel"
      "uptime"
      "packages"
      "shell"
      "display"
      "de"
      "wm"
      "wmtheme"
      "theme"
      "icons"
      "font"
      "cursor"
      {
        # {?version}…{?} = a conditional block: with no version detected, no loose space is left.
        type = "terminal";
        format = "{process-name}{?version} {version}{?}";
      }
      "terminalfont"
      "cpu"
      "gpu"
      "memory"
      "swap"
      "disk"
      "localip"
      "battery"
      "poweradapter"
      "locale"
      "break"
      "colors"
    ];
  };
}
