# IMMICH: a self-hosted Google Photos (native, systemd). Uploads live in /srv/photos/immich, and
# /srv/photos/archive is an external library I manage. Layout and traps: docs/notes/services/immich.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.immich;
in
{
  # I manage the archive, and immich reads it through its OWN group: PrivateUsers maps every other
  # group to nobody inside the sandbox, so a shared `photos` group would read as no access.
  users.users = lib.mkIf config.my.services.immich {
    v1cferr.extraGroups = [ cfg.group ];
  };

  # Outside /home on purpose: the unit runs with ProtectHome, so ~/Pictures is invisible to it.
  # The module only FIXES the mode of mediaLocation (`e`), so creating it is on this side.
  systemd.tmpfiles.rules = lib.mkIf config.my.services.immich [
    "d /srv/photos         0755 root      root       - -"
    "d ${cfg.mediaLocation} 0700 ${cfg.user} ${cfg.group} - -"
    "d /srv/photos/archive 2750 v1cferr   ${cfg.group} - -" # setgid: files I add inherit the group
  ];

  services.immich = {
    enable = config.my.services.immich;
    # Unstable: stable's 2.x is EOL and flagged insecure (two CVEs); 3.x only ships from 26.11.
    # The stable MODULE runs it as is (compared on 28/09/2026). Drop this line on the 26.11 upgrade.
    package = pkgs.unstable.immich;
    mediaLocation = "/srv/photos/immich";
    # `settings` stays null ON PURPOSE: a non-null value makes the WHOLE admin panel read-only.
    # The server listens on localhost:2283 and the phone reaches it through Caddy (`photos`).
  };

  # Sockets only: duo-db (Docker) already holds 127.0.0.1:5432, and immich talks over
  # /run/postgresql anyway. Without this the native postgres dies on a port conflict at boot.
  services.postgresql.settings.listen_addresses = lib.mkIf config.my.services.immich (lib.mkForce "");
}
