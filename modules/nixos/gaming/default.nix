# Games (system level): clients/runtimes that need an FHS-wrap or the firewall.
{ ... }:

{
  imports = [
    ./hydralauncher.nix # Hydra's torrent port open (the app itself is in modules/home/apps)
    ./steam.nix # the Steam client plus Proton-GE plus gamemode plus ntsync (Remote Play/LAN with the firewall)
  ];
}
