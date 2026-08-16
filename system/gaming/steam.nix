# STEAM: the client plus the Proton runtime. System level and mandatory, since programs.steam
# FHS-wraps the client and injects the steam-runtime. Games/prefixes are STATE (rule 6).
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
}
