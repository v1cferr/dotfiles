# ═══════════════════════════════════════════════════════════════════════════
# DECLARATIVE BACKUP (restic): user state to Google Drive, ENCRYPTED.
#
# restic encrypts at rest, deduplicates and versions. `check` verifies integrity.
#
# THE PAIR WITH btrbk (btrbk.nix): the hourly local snapshot covers "I just overwrote it";
# THIS one covers "the disk died / the house burned down". A snapshot on the same disk is not
# a backup, and a sync is not a backup, because deleting propagates. Only restic is a backup
# (rule 6).
#
# The password is a SECRET (sops: restic_password). Without it the repo is encrypted garbage.
#
# ── WHY THE DRIVE ONLY (05/08/2026) ────────────────────────────────────────
# The destination used to be the Seagate HDD (/mnt/seagate-old/restic) and it left. It was not
# about space: it was the ONLY copy of the live home, on a ~2009 Momentus 7200.4 with 840
# thousand load cycles (40% past spec) and 348 CRC errors, INSIDE the same machine, so it
# disappears with it in a theft or a fire. An offsite copy wins on the failure modes that
# actually happen. The accepted price: restoring goes over the network and depends on the
# Google account. Measured on the 1st snapshot: 40.6 GiB read, 23.6 GiB on the wire, 15 min.
#
# THE DRIVE IS VERIFIED: `check --read-data` rereading the 189 packs returned "no errors were
# found" on 05/08/2026. The Seagate repo was still NOT deleted, and that is not indecision, it
# is HISTORY: the Drive has 1 snapshot (from today) and the Seagate has 13, with the 7d/4w/6m
# window. Deleting now would lose every version older than today, which is exactly what saves
# you when a file got corrupted weeks ago and nobody noticed. The repo is static (nothing
# writes to it anymore) and the disk has 195 G free, so keeping it costs nothing. Delete it
# when the Drive accumulates an equivalent window.
# Without the target here the `restic-home` wrapper stops existing, so to read the frozen repo
# it is restic directly:
#   sudo restic -r /mnt/seagate-old/restic --password-file /run/secrets/restic_password snapshots
#
# ── SEEING WHAT IS INSIDE THE BACKUP ───────────────────────────────────────
# The repo is an encrypted blob: rclone does NOT decrypt it, restic does. To browse it as a
# folder (one directory per snapshot, read-only):
#   sudo restic-home-gdrive mount /mnt/backup     # Ctrl+C unmounts
# The wrapper the module generates already carries RCLONE_CONFIG, the password and rclone on
# the PATH.
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # The nixpkgs module already declares `RuntimeDirectory=restic-backups-home-gdrive`, so
  # systemd creates (and deletes on stop) this directory before the preStart. We only reuse it.
  runtimeDir = "/run/restic-backups-home-gdrive";
in
lib.mkIf config.my.services.restic {
  # A MOUNT POINT to BROWSE the backup in the file manager (the `backup-browse` alias). Owned
  # by the USER because whoever mounts has to be the user: a FUSE mount is private to whoever
  # mounted it, so a `sudo restic mount` produces a folder Dolphin cannot open, which was the
  # defect of the alias's 1st version.
  #
  # It lives in /mnt and NOT in the home on purpose: a mountpoint inside /home/v1cferr would
  # enter the backup's `paths` and fall into the SAME trap as ~/FAI-workstation (an lstat on
  # somebody else's FUSE, so restic exits 3 and the prune does not run). Outside the home the
  # problem does not even exist.
  #
  # /mnt/arch-antigo was created here until 11/08/2026 and left for
  # system/services/arch-legacy.nix: that mount stopped being an on-demand lookup and became a
  # permanent service, so its directory cannot depend on this toggle.
  systemd.tmpfiles.rules = [
    "d /mnt/backup 0755 v1cferr users -" # the home repo, on the Drive
  ];

  systemd.services.restic-backups-home-gdrive = {
    # A TRAP that already cost the entire Arch archive service: the nixpkgs module puts ONLY
    # ssh on the PATH (`path = [ config.programs.ssh.package ]`), and restic's `rclone:`
    # backend EXECUTES the rclone binary. Without this mkAfter, it dies right at the start with
    # "rclone: executable file not found in $PATH".
    path = lib.mkAfter [ pkgs.rclone ];

    # A WRITABLE COPY of rclone.conf, the same pattern as ~/Drive
    # (home/services/drive-mount.nix), and here it is NOT cosmetic: it is what stops this
    # backup from WRECKING everyone who reads the same secret as the USER (`backup-browse`, and
    # the old Arch archive mount).
    #
    # The module's `rcloneConfigFile` option only sets `RCLONE_CONFIG=<path>`, and this service
    # runs as ROOT. rclone renews the OAuth token and persists the new one OVER the file it was
    # pointed at, and root has permission, so it succeeds, and the new file is born
    # `root:users`. That ERASES the `owner = "v1cferr"` that sops put on
    # /run/secrets/rclone_gdrive_conf, and every consumer that runs as the USER starts dying
    # unable to read rclone.conf: `backup-browse` (the alias in home/shell/zsh.nix), ~/Drive
    # and, since 11/08/2026 and most sensitive to it because it is a service and not a command,
    # the permanent mount of the old Arch archive (home/services/arch-legacy-mount.nix).
    # Diagnosed on 07/08/2026: boot at 07:29, sops sets v1cferr, the delayed 03:00 backup ran
    # at 07:54:39, and the secret's mtime became root:users at 07:54:40. In practice the backup
    # browser was broken almost always and "fixed itself" on reboot.
    # The user reading from here is read-only (0400), so they have no way to reintroduce the
    # bug.
    environment.RCLONE_CONFIG = "${runtimeDir}/rclone.conf";
    # mkBefore, NOT mkAfter: the `initialize = true` puts a `restic cat config || restic init`
    # at the beginning of the SAME preStart, and that one already talks to the Drive. Copying
    # after it would make the service die on the first command with a nonexistent rclone.conf.
    preStart = lib.mkBefore ''
      install -m600 ${config.sops.secrets.rclone_gdrive_conf.path} ${runtimeDir}/rclone.conf
    '';
  };

  services.restic.backups.home-gdrive = {
    # `rclone:<remote>:<path>`: restic starts an `rclone rcd` and talks HTTP with it. The path
    # names the MACHINE (the EX-B560M-V5 board) so it can coexist with other backups there.
    repository = "rclone:gdrive:BACKUPS_EX-B560M-V5/HOME";

    passwordFile = config.sops.secrets.restic_password.path;

    # An rclone.conf with the OAuth token is a SECRET (rule 12). NEVER the `rcloneConfig`
    # option (an attrset): it leaks the token into /nix/store, which is world-readable. And
    # also NOT `rcloneConfigFile`: it points RCLONE_CONFIG straight at the secret, and the
    # service runs as root, see the `environment.RCLONE_CONFIG` above, which passes the
    # writable copy instead.

    initialize = true; # creates the repo on the 1st backup

    paths = [ "/home/v1cferr" ];

    # excludes what is regenerable (cache, builds, garbage). Zen's `storage` (site data) is NOT
    # cache, so it stays; only cache2 (the Firefox/Zen http cache) goes.
    exclude = [
      # ANOTHER MACHINE'S MOUNT, which is not "regenerable", it is SOMEBODY ELSE'S. Without
      # this line the backup FAILED INTERMITTENTLY (05/08/2026): `error: lstat
      # /home/v1cferr/FAI-workstation: permission denied`, so restic exits 3, and since
      # `backup` is the 1st of three ExecStart entries, the `unlock` and the `forget --prune`
      # did NOT run, and retention silently did not apply. The cause is permissions, not
      # config: the mount is the USER's FUSE (rclone SFTP,
      # home/services/fai-workstation-mount.nix) and the backup runs as ROOT, which does not
      # enter somebody else's FUSE. It is intermittent because it only exists while the FAI VPN
      # is up: the 06:44 run passed, the 14:55 one did not.
      # `--one-file-system` does not save you: it prevents DESCENDING into the mount, but
      # restic still lstats the mount point. A remote machine's backup should never enter here.
      "/home/v1cferr/FAI-workstation"

      # THE SAME TRAP, SECOND VICTIM, and this one hurt more because it is PERMANENT.
      # `~/Drive` is the rclone gdrive (home/services/drive-mount.nix), the user's FUSE just
      # like the one above, and root does not lstat it either. The difference is that
      # FAI-workstation only exists with the VPN up (an intermittent, and therefore visible,
      # failure): the Drive mounts on EVERY boot, so from 06/08/2026 on the service started
      # failing EVERY NIGHT and the prune stopped running for good.
      # MEASURED on 09/08/2026: the last successful `forget --prune` was 05/08 15:46, four days
      # with no retention being applied at all.
      # THE SIZE OF THE DAMAGE WAS SMALL, and the reason matters so the next case is not
      # overestimated: the recovery run removed ONE snapshot and freed 4.9 MiB in 14 s. With
      # `--keep-daily 7` and only 5 distinct days in the repo, NOTHING had aged out of the
      # window yet, and the only excess was the same-day duplicate. The real damage would only
      # start after ~7 distinct days, when each new day starts pushing one out and none leaves.
      # WHAT ACTUALLY HAS TEETH is the `unlock`, which is also an ExecStart and also was not
      # running: a stuck lock from an interrupted run BLOCKS the entire backup, and that does
      # not depend on how much time passed.
      # THE LESSON, which is bigger than this file: a user FUSE mount INSIDE `paths` breaks the
      # backup by construction. A new mount point in /home/v1cferr enters HERE in the same
      # commit that creates it. This is the third time this same bug has appeared under a
      # different name.
      # And the service failing every night is not only noise: "restic failed" becomes the
      # normal state, and then the REAL failure (the Drive down, an expired OAuth token, a
      # stuck lock) arrives with nothing to distinguish it from the usual noise.
      "/home/v1cferr/Drive"

      "/home/v1cferr/.cache"
      "/home/v1cferr/.local/share/Trash"
      # ── Bulky and RE-OBTAINABLE (no sense in encrypting and keeping) ──
      "/home/v1cferr/Downloads" # transient
      "/home/v1cferr/Games" # games (PS3 and so on), re-downloadable from the sources
      "/home/v1cferr/.local/share/bottles" # Wine prefixes (~154G): reinstallable games. NOTE: game saves live in here, so if any is irreplaceable, back it up separately.
      "/home/v1cferr/.local/share/Steam" # the Steam library, if any (re-downloadable)
      "**/node_modules"
      "**/.direnv"
      "**/target" # Rust builds
      "**/__pycache__"
      "**/.venv"
      "**/Cache"
      "**/Cache_Data"
      "**/CachedData"
      "**/Code Cache"
      "**/GPUCache"
      "**/ShaderCache"
      "**/cache2" # the Firefox/Zen http cache (keeps 'storage')
      "**/startupCache"
    ];

    timerConfig = {
      OnCalendar = "03:00";
      Persistent = true; # runs at boot if it missed the schedule
      RandomizedDelaySec = "30min";
    };

    extraBackupArgs = [
      # The option that decides VIABILITY (it is not an optimization): on the Drive the cost is
      # per API CALL, not per byte, and there are 255 THOUSAND files here. In 128 MiB objects
      # (restic's maximum) that becomes a few thousand objects.
      "--pack-size=128"
      "--one-file-system" # does not cross into another FS if a nested mount appears
      "--exclude-caches" # skips directories with a CACHEDIR.TAG (the freedesktop standard)
    ];

    # Progress once a minute in the journal. At the default (1 fps) a 15 min upload would
    # become thousands of lines.
    progressFps = 0.0167;

    # retention: an automatic prune after each backup
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
      # Pruning a remote repo REPACKS: it downloads partially used packs and uploads them back.
      # With no ceiling, a bad prune would become hours of traffic. What does not fit today
      # gets pruned on the next run.
      "--max-repack-size=2G"
    ];

    # `--read-data-subset` stays OUT on purpose: rereading means DOWNLOADING. 10% a day of a
    # ~24 GiB repo would be ~2.4 GiB of download EVERY DAY, forever. Here the check is
    # STRUCTURAL only (indexes and trees), which is metadata and comes cheap. Reading the data
    # in full is MANUAL and deliberate:
    #   sudo restic-home-gdrive check --read-data
    checkOpts = [ ];
  };
}
