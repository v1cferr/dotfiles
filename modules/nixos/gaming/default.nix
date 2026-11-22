# Games (system level): clients/runtimes that need an FHS-wrap or the firewall.
{ ... }:

{
  imports = [
    ./game-fence.nix # while a game runs, every other app and system service gets idle priority and 2 CPUs
    ./hydralauncher.nix # Hydra's torrent port open (the app itself is in modules/home/apps)
    ./steam.nix # the Steam client plus Proton-GE plus gamemode plus ntsync (Remote Play/LAN with the firewall)
  ];
}
