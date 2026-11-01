# Hydra Launcher, the system side: its torrent port open, so peers can dial in instead of only being
# dialed, and its games kept out of the backup. The router forwards the same port: docs/notes/apps/hydralauncher.md
{ config, ... }:

let
  # Hard-coded in the app (DEFAULT_TORRENT_PORT in torrent-client.ts), with no setting to move it.
  torrentPort = 5881;
in
{
  # One Wine prefix per game, the installed game inside: tens of GiB, re-obtainable. The downloads
  # land in ~/Games/Hydra, which the backup already leaves out with the rest of ~/Games.
  my.backup.exclude = [ "${config.users.users.v1cferr.home}/.config/hydralauncher/wine-prefixes" ];

  networking.firewall = {
    allowedTCPPorts = [ torrentPort ]; # libtorrent's peer connections
    allowedUDPPorts = [ torrentPort ]; # DHT and uTP, the bulk of a modern swarm
  };
}
