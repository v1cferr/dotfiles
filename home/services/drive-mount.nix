# ~/Drive: the ROOT of Google Drive mounted as a local folder (rclone mount plus a VFS cache), so
# it shows up in Dolphin as a normal folder, with a bookmark in home/apps/dolphin.nix.
#
# It serves the real case: "sometimes I need a file I do not have here but that is on the Drive".
# You see everything right away (Documentos, César, Mãe, SENAC and so on), with no downloading.
#
# ── WHY A MOUNT AND NOT BISYNC (decided on 05/08/2026) ──────────────────────
# The first version here was `rclone bisync`. It was swapped after LISTING the remote and seeing
# that the root holds ~19.6 GiB of real archive (family photos, documents):
#   • bisync would download those 19.6 GiB onto the NVMe to give the same access the mount gives
#     with zero downloading;
#   • and a sync PROPAGATES, so deleting locally would delete on the Drive, family folder
#     included. In a mount every operation is explicit and singular; there is no algorithm
#     reconciling two listings that could conclude "the other side should be empty".
# What you lose: OFFLINE access and editing with no network. An accepted trade, since what needs
# to work offline is the backup (restic), and that is another module.
#
# ── THIS IS NOT A BACKUP ────────────────────────────────────────────────────
# It is a WINDOW into the Drive: deleting here deletes there, for real. The backup is restic
# (system/services/restic.nix), and that is the only thing that satisfies rule 6.
#
# The restic repo lives in BACKUPS_EX-B560M-V5/ and is EXCLUDED from the mount: it is ~48 GiB of
# encrypted blobs that would only pollute the file manager, and an accidental Delete in there
# CORRUPTS the backup. To look inside the backup there is `backup-browse` (a restic mount), which
# is read-only.
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:

let
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
        # At login the network usually takes a few seconds. Without this systemd would give up
        # after 5 quick failures (StartLimit) and the folder would stay empty until a manual
        # start.
        StartLimitIntervalSec = 0;
      };

      Service = {
        # Supported by rclone (it is in `rclone mount --help`, the systemd section): the unit only
        # goes "started" AFTER the mountpoint is ready. With Type=simple, Dolphin could open the
        # folder before it exists and cache it as "empty".
        Type = "notify";

        # A WRITABLE COPY of rclone.conf. rclone renews the OAuth token and tries to persist the
        # new one into the config file; against the sops secret (0400, in a non-writable
        # directory) that becomes `Failed to save config … permission denied`. It is not fatal,
        # but it is a recurring ERROR in the journal hiding a real error.
        # `%t` = XDG_RUNTIME_DIR (/run/user/1000), a tmpfs, 0600.
        #
        # The `--config` goes on the command and NOT as RCLONE_CONFIG in the environment:
        # `programs.rclone` generates the rclone.conf for the `faiws` remote, and exporting the
        # variable would make the FAI mount look for its remote in the wrong file. (rclone's docs
        # also warn that a systemd unit does not inherit the environment, another reason for the
        # flag.)
        # WARNING: THE MOUNTPOINT HAS TO BE EMPTY. rclone refuses with "…is not empty, use
        # --allow-non-empty to mount anyway", and `--allow-non-empty` stays OUT on purpose:
        # mounting over an existing file HIDES it, and then you have invisible data that only
        # reappears when the mount goes down. It cost the first start (05/08/2026): the bisync
        # version of this module created an RCLONE_TEST here, and the orphaned 0-byte file locked
        # the mount into a restart loop.
        # If the mount does not come up, check `ls -a ~/Drive` BEFORE suspecting the network.
        ExecStartPre = [
          "${pkgs.coreutils}/bin/mkdir -p ${cfg.local}"
          "${pkgs.coreutils}/bin/install -m600 /run/secrets/rclone_gdrive_conf %t/rclone-gdrive.conf"
        ];

        ExecStart = lib.concatStringsSep " " [
          "${pkgs.rclone}/bin/rclone --config %t/rclone-gdrive.conf mount"
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

        # rclone unmounts on its own on SIGTERM; this is the safety net for a hung mount (the `-`
        # ignores a failure when it is already unmounted). It has to be NixOS' setuid WRAPPER,
        # since the package's fusermount3 has no privilege.
        ExecStopPost = "-/run/wrappers/bin/fusermount3 -uz ${cfg.local}";

        Restart = "on-failure";
        RestartSec = 10;
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
