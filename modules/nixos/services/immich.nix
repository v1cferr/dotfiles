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
    # Not the default "localhost": it resolved to [::1] only, and my.ingress proxies 127.0.0.1 (502).
    host = "127.0.0.1";
    # `settings` stays null ON PURPOSE: a non-null value makes the WHOLE admin panel read-only.
  };

  # Sockets only: duo-db (Docker) already holds 127.0.0.1:5432, and immich talks over
  # /run/postgresql anyway. Without this the native postgres dies on a port conflict at boot.
  services.postgresql.settings.listen_addresses = lib.mkIf config.my.services.immich (lib.mkForce "");

  # Immich dumps its OWN database into mediaLocation (upstream's restore path), so the photos and
  # the database travel together. The check fails the backup if those dumps stopped (8 days: trips).
  my.backup = lib.mkIf config.my.services.immich {
    paths = [ "/srv/photos" ];
    prepare = ''
      if [ -z "$(find ${cfg.mediaLocation}/backups -name '*.sql.gz' -mtime -8 2>/dev/null)" ]; then
        echo "backup: no Immich database dump newer than 8 days in ${cfg.mediaLocation}/backups" >&2
        exit 1
      fi
    '';
  };
}
