# ═══════════════════════════════════════════════════════════════════════════
# Jellyfin: a native media server (systemd, 24/7, it comes up at boot).
#
# Migrated from the Arch Docker stack to NixOS' native service: isolated in the 'jellyfin' user,
# with no container overhead. The rest of the old stack (jellyseerr, the *arr apps, qbittorrent,
# cloudflared) comes later, one module at a time in this system/media/.
#
# The library is in /srv/media (an SSD), shared through the 'media' group (I manage the files;
# jellyfin reads them). The LIBRARIES themselves (what is a Movie or a Series) are configured in
# the web UI (localhost:8096) on the 1st visit; that lives in jellyfin's DB, not here.
#
# DLNA (for the TV): it stopped being core in 10.10, it is the official "DLNA" plugin, installed
# through the web UI (Dashboard > Plugins). It discovers the network interface on its own, but it
# only counts as "virtual" what is listed in VirtualInterfaceNames (Dashboard > Network): with no
# 'docker'/'br-' there, it announces the Docker bridge's IP and the TV does not find the server.
# ═══════════════════════════════════════════════════════════════════════════
{ config, lib, ... }:

{
  # The media's shared group: the owner is me (I copy/manage), the reader is jellyfin.
  users.groups.media = { };
  users.users.v1cferr.extraGroups = [ "media" ]; # (it adds to wheel/networkmanager)
  users.users.jellyfin.extraGroups = [ "media" ]; # the service reads the library

  # /srv/media with setgid (the '2' in 2775): everything created inside inherits the 'media' group,
  # so jellyfin/the *arr apps and I see the same files without fighting over permissions.
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

  # Upstream uses UMask 0077: the cover art/nfo jellyfin downloads are born 0600 and I cannot read
  # or move them. 0002 makes those files inherit the 'media' group with read access.
  systemd.services.jellyfin.serviceConfig.UMask = lib.mkForce "0002";
}
