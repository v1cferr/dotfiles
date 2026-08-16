# JELLYFIN: a native media server (systemd, 24/7). The library is /srv/media, shared through the
# 'media' group. The UMask override, DLNA on the TV and the rest: docs/notes/jellyfin.md
{ config, lib, ... }:

{
  # The media's shared group: the owner is me (I copy/manage), the reader is jellyfin.
  users.groups.media = { };
  users.users.v1cferr.extraGroups = [ "media" ]; # (it adds to wheel/networkmanager)
  users.users.jellyfin.extraGroups = [ "media" ]; # the service reads the library

  # /srv/media with setgid (the '2' in 2775): everything inside inherits the 'media' group.
  systemd.tmpfiles.rules = [
    "d /srv/media          2775 v1cferr media - -"
    "d /srv/media/media    2775 v1cferr media - -" # movies/series (the library)
    "d /srv/media/media/Filmes 2775 v1cferr media - -" # the movie library's root
    "d /srv/media/torrents 2775 v1cferr media - -" # downloads (a future qbittorrent)
  ];

  services.jellyfin = {
    enable = config.my.services.jellyfin;
    openFirewall = true; # it opens 8096/8920 (web) plus 1900/7359 UDP (DLNA discovery) on the LAN
  };

  # Upstream's UMask 0077 makes the downloaded art/nfo 0600 and unreadable to me; 0002 fixes it.
  systemd.services.jellyfin.serviceConfig.UMask = lib.mkForce "0002";
}
