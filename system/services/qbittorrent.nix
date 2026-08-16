# qBittorrent: the headless download client plus its Web UI, in the 'media' group (rule 6: the
# save paths and the categories are state, set in the UI). See docs/notes/services/jellyfin.md
{ config, ... }:

{
  services.qbittorrent = {
    enable = config.my.services.qbittorrent;
    openFirewall = true; # it opens the torrent port (peers) plus the Web UI on the LAN
    webuiPort = 8080; # the web panel (the same as the old setup)
    user = "qbittorrent";
    group = "media"; # a shared group, so it writes into the /srv/media library
  };
}
