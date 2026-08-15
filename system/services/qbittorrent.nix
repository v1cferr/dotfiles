# ═══════════════════════════════════════════════════════════════════════════
# qBittorrent: the download client (headless qbittorrent-nox plus a Web UI), on systemd.
#
# It runs in the 'media' group (the same as jellyfin) so it can write to /srv/media/torrents. The
# Web UI sits on 8080 (the same as the old Docker stack's WEBUI_PORT). The SAVE PATH and the
# categories are adjusted in the Web UI (localhost:8080); that is qBittorrent's state.
# The initial login: user 'admin', with a temporary password in the log
# (journalctl -u qbittorrent).
# ═══════════════════════════════════════════════════════════════════════════
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
