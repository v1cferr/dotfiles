# MONITORS = the SINGLE SOURCE of the connector names (rule 11). It was the repo's worst case of
# duplication: DP-2 in 8 files and HDMI-A-3 in 7, across Nix, Lua and QML, so changing a monitor
# (or a cable) meant hunting a string through everything.
#
# Only the NAMES live here, which is what was repeated. The mode/position/refresh stay in
# hypr/lua/monitors.lua: each appears once, and they are not the SSOT of anything.
#
# WHY IN system/ AND NOT IN home/ (changed on 04/08/2026): a connector is a HARDWARE fact, and
# whoever needs it is not only the user. Sunshine (a system service) picks WHICH monitor to
# capture by this name. A system module cannot read a home option without naming the user and
# reaching inside `home-manager.users.<x>`; the other direction is clean and idiomatic, because
# home-manager runs as a NixOS module and hands `osConfig` ready to every home module. So the
# option lives here and EVERYBODY reads downward.
#
# The consumers in system/ read `config.my.monitors.<n>`; the ones in home/ read
# `osConfig.my.monitors.<n>` (the same mechanics as my.fonts in hardware/fonts.nix).
# The HOT-RELOAD ones (Hyprland/Quickshell) read the data files generated in
# home/desktop/monitors.nix, because Nix does not write inside the symlinked trees (the same
# mechanics as the palette in palette.nix).
#
# NO `default` on purpose (04/08/2026): DP-2/HDMI-A-3 are THIS board's connectors, and this here is
# the machine-agnostic tree. A hardware default in system/ is the lie that only shows up on host
# nº 2 (the laptop would inherit connectors it does not have, and nobody would see the error).
# With no default, the module requires the HOST to declare it: the value lives in
# hosts/<host>/default.nix, and a new host that forgets BREAKS at eval, loudly and early.
# ═══════════════════════════════════════════════════════════════════════════
{ lib, ... }:

{
  options.my.monitors = {
    primary = lib.mkOption {
      type = lib.types.str;
      description = "The MAIN monitor's connector: origin 0x0, workspaces 1 to 4. Set by the host.";
    };
    secondary = lib.mkOption {
      type = lib.types.str;
      description = "The SECONDARY monitor's connector: on the left, workspaces 5 to 8. Set by the host.";
    };
  };
}
