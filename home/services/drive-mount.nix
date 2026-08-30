# ~/Drive: the Google Drive root mounted as a normal folder (rclone plus a VFS cache). It is a
# WINDOW, NOT a backup: deleting here deletes there. Why not: docs/notes/boot-and-storage/restic.md
{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    coreutils
    rclone
    ;

  cfg = config.my.drive;
in
{
  options.my.drive = {
    local = lib.mkOption {
      type = lib.types.str;
      default = "/home/v1cferr/Drive";
      description = "The mountpoint. Also read by Dolphin's bookmark (SSOT, rule 11).";
    };
    remote = lib.mkOption {
      type = lib.types.str;
      default = "gdrive:";
      description = "The rclone remote. `gdrive:` = the Drive's root; the remote comes from sops' rclone.conf.";
    };
  };

  config = lib.mkIf osConfig.my.services.drive-mount {
    systemd.user.services.drive-mount = {
      Unit = {
        Description = "Google Drive mounted at ${cfg.local} (rclone mount)";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
        # At login the network takes a few seconds; without this systemd gives up after 5 quick tries.
        StartLimitIntervalSec = 0;
      };

      Service = {
        # Type=notify: the unit only goes "started" AFTER the mountpoint is ready, so Dolphin cannot
        # open the folder early and cache it as "empty".
        Type = "notify";

        # A WRITABLE COPY of rclone.conf (rclone rewrites the OAuth token) and --config on the COMMAND,
        # never RCLONE_CONFIG. THE MOUNTPOINT MUST BE EMPTY,: docs/notes/boot-and-storage/restic.md
        ExecStartPre = [
          "${coreutils}/bin/mkdir -p ${cfg.local}"
          "${coreutils}/bin/install -m600 /run/secrets/rclone_gdrive_conf %t/rclone-gdrive.conf"
        ];

        ExecStart = lib.concatStringsSep " " [
          "${rclone}/bin/rclone --config %t/rclone-gdrive.conf mount"
          cfg.remote
          cfg.local
          # It hides the restic repo from the mount (see the header): noise in Dolphin, and an
          # accidental Delete in there would corrupt the backup.
          "--exclude BACKUPS_EX-B560M-V5/**" # no quotes: systemd does not expand a glob in Exec*
          # "writes": a READ goes straight through (streaming, it does NOT pile up on disk), and
          # only what you write/copy is cached until it uploads. The same choice as the FAI mount.
          "--vfs-cache-mode writes"
          "--vfs-cache-max-age 6h" # it evicts the write cache quickly
          "--vfs-cache-max-size 2G" # the on-disk cache ceiling (~/.cache/rclone)
          "--dir-cache-time 5m" # the listing cached for 5min, so browsing is FAST (F5 reloads)
          "--buffer-size 8M" # read-ahead RAM per open file
          "--timeout 30s" # the I/O timeout (it does not hang forever if the network drops)
          "--contimeout 15s" # the connection timeout
          "--log-systemd" # the log goes to the journal with the right priority
        ];

        # A safety net for a hung mount (the `-` ignores an already-unmounted one). It has to be NixOS'
        # setuid WRAPPER, since the package's fusermount3 has no privilege.
        ExecStopPost = "-/run/wrappers/bin/fusermount3 -uz ${cfg.local}";

        Restart = "on-failure";
        RestartSec = 10;
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
