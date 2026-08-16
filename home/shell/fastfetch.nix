# fastfetch, with the module list repeated in full because there is no per-module override.
# The terminal field uses {process-name}: VS Code's cmdline blew up the layout.
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
