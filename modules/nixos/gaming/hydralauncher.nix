# Hydra Launcher, the system side: its torrent port open, so peers can dial in instead of only being
# dialed. The router forwards the same number (router-ssot checks it): docs/notes/apps/hydralauncher.md
_:

let
  # Hard-coded in the app (DEFAULT_TORRENT_PORT in torrent-client.ts), with no setting to move it.
  torrentPort = 5881;
in
{
  networking.firewall = {
    allowedTCPPorts = [ torrentPort ]; # libtorrent's peer connections
    allowedUDPPorts = [ torrentPort ]; # DHT and uTP, the bulk of a modern swarm
  };
}
