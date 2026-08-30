# The watcher that turns the mouse's ONBOARD DPI button into an OSD, the way Synapse does on
# Windows. Why it polls, and what a poll costs: docs/notes/hardware/razer.md
{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # Every package this module reaches for, named ONCE and up front: an entry that stops being
  # used fails the build under deadnix, so the list cannot rot into a lie (rule 16).
  inherit (pkgs) razer-dpi;

  qsPkg = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  systemd.user.services.razer-dpi = {
    Unit = {
      Description = "Razer DPI watcher (it pushes the OSD when the onboard button changes the DPI)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${razer-dpi}/bin/razer-dpi watch";
      # `qs` is the ONLY thing called out of PATH, and it is how the OSD gets pushed.
      Environment = [ "PATH=${lib.makeBinPath [ qsPkg ]}" ];
      # With no mouse the watcher idles on a 5 s rescan instead of exiting, so unplugging and
      # replugging needs no restart. Restart is the belt for a crash, not the hotplug path.
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
