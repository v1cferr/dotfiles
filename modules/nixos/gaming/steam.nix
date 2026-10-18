# STEAM: the client plus the Proton runtime, system level since programs.steam FHS-wraps it.
# Games and prefixes are STATE (rule 6). GameMode's power hold: docs/notes/hardware/power.md
{ config, pkgs, ... }:

let
  inherit (pkgs) coreutils power-profiles-daemon proton-ge-bin;
  systemctl = "${config.systemd.package}/bin/systemctl";
in
{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Steam Remote Play / Link (streaming to other devices)
    localNetworkGameTransfers.openFirewall = true; # it downloads games from another Steam PC on the LAN instead of the internet
    extraCompatPackages = [ proton-ge-bin ]; # Proton-GE: better compatibility than the official Proton (fixes/codecs)
  };

  # Feral GameMode through `gamemoderun %command%`: I/O priority, split-lock off, and the CPU boost
  # as a power-profiles-daemon HOLD, so leaving a game returns to the profile I had picked.
  programs.gamemode = {
    enable = true;
    settings = {
      # The governor stays put: `performance` would lock intel_pstate's EPP away from ppd.
      general.desiredgov = "powersave";
      custom.start = "${systemctl} --user start gamemode-performance.service";
      custom.end = "${systemctl} --user stop gamemode-performance.service";
    };
  };
  # The group gamemode's polkit rule asks for: without it every helper died on "Not authorized".
  users.users.v1cferr.extraGroups = [ "gamemode" ];

  # The hold lives as long as this process; ppd drops it on exit, on a crash, or on a manual switch.
  systemd.user.services.gamemode-performance = {
    description = "Holds the performance power profile while GameMode is active";
    bindsTo = [ "gamemoded.service" ]; # a dead gamemoded never leaves the CPU boosted
    after = [ "gamemoded.service" ];
    serviceConfig.ExecStart = "${power-profiles-daemon}/bin/powerprofilesctl launch --profile performance --reason GameMode --appid gamemode ${coreutils}/bin/sleep infinity";
  };

  # NT sync primitives in the kernel: Proton 11/GE pick up /dev/ntsync on their own (beats fsync).
  boot.kernelModules = [ "ntsync" ];
}
