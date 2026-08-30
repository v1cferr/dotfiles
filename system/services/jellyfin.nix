# JELLYFIN: a native media server (systemd, 24/7). The library is /srv/media, shared through the
# 'media' group. The UMask override, DLNA on the TV and the rest: docs/notes/services/jellyfin.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Every package this module reaches for, named ONCE and up front: an entry that stops being
  # used fails the build under deadnix, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    gnugrep
    iproute2
    writeShellScript
    ;

  # It exits 0 on timeout ON PURPOSE: this is a best-effort delay, and a machine with no network
  # still has to bring its server up instead of failing the unit.
  waitForIpv4 = writeShellScript "jellyfin-wait-for-ipv4" ''
    for _ in $(seq 1 30); do
      ${iproute2}/bin/ip -4 route show default | ${gnugrep}/bin/grep -q . && exit 0
      sleep 1
    done
    exit 0
  '';
in
{
  # The media's shared group: the owner is me (I copy/manage), the reader is jellyfin.
  users.groups.media = { };
  # The jellyfin USER only exists when the SERVICE does, so it sits behind the toggle: with the
  # panel off it stood alone as a half-declared user and the EVAL failed (found by the boot test).
  users.users = lib.mkMerge [
    { v1cferr.extraGroups = [ "media" ]; } # (it adds to wheel/networkmanager)
    (lib.mkIf config.my.services.jellyfin {
      jellyfin.extraGroups = [ "media" ]; # the service reads the library
    })
  ];

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
  # Behind the toggle for the same reason as the user: with no service there is no unit to override.
  systemd.services = lib.mkIf config.my.services.jellyfin {
    jellyfin.serviceConfig = {
      UMask = lib.mkForce "0002";
      # network-online.target is NOT enough, and the unit already orders after it: wait-online
      # returns as soon as ONE address family is up, and here IPv6 by SLAAC beats DHCPv4. On the
      # boot of 29/08/2026 the target was reached at 19:03:11 and enp7s0 only got its IPv4 at
      # 19:03:13, so the DLNA plugin enumerated interfaces in between and published the server on
      # 127.0.0.1. That failure HIDES ITSELF: the web UI answers normally and only the TV, which
      # depends on SSDP discovery, cannot find anything. Waiting for the default ROUTE is what
      # actually means "IPv4 is usable", and the docker/br- bridges never create one.
      ExecStartPre = [ "${waitForIpv4}" ];
    };
  };
}
