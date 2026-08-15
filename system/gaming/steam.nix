# ═══════════════════════════════════════════════════════════════════════════
# STEAM: the client plus the Proton runtime (system level, mandatory: programs.steam FHS-wraps the
# client and injects the steam-runtime). unfree is already allowed (core.nix) and the 32-bit libs
# are already on for Wine/Proton (gpu.nix: enable32Bit).
#
# Games/prefixes are STATE (~/.local/share/Steam), so they are outside the restic backup, like
# Bottles (rule 6). The MangoHud overlay (home/apps) is injected through `mangohud %command%` in
# the game's launch options. gamemode: use `gamemoderun %command%` (or both together) for the
# governor/CPU boost while playing.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Steam Remote Play / Link (streaming to other devices)
    localNetworkGameTransfers.openFirewall = true; # it downloads games from another Steam PC on the LAN instead of the internet
    extraCompatPackages = [ pkgs.proton-ge-bin ]; # Proton-GE: better compatibility than the official Proton (fixes/codecs)
  };

  # Feral GameMode: the performance governor plus I/O priority while the game runs (activated
  # through `gamemoderun %command%`). A CPU gain with no overclock.
  programs.gamemode.enable = true;
}
