# STEAM: the client plus the Proton runtime, system level since programs.steam FHS-wraps it.
# Games and prefixes are STATE (rule 6). No note: nothing here needs more than this.
{ pkgs, ... }:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Steam Remote Play / Link (streaming to other devices)
    localNetworkGameTransfers.openFirewall = true; # it downloads games from another Steam PC on the LAN instead of the internet
    extraCompatPackages = [ pkgs.proton-ge-bin ]; # Proton-GE: better compatibility than the official Proton (fixes/codecs)
  };

  # Feral GameMode: the performance governor plus I/O priority, through `gamemoderun %command%`.
  programs.gamemode.enable = true;

  # NT sync primitives in the kernel: Proton 11/GE pick up /dev/ntsync on their own (beats fsync).
  boot.kernelModules = [ "ntsync" ];
}
