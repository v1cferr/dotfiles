# BACKUP (restic): user state to Google Drive, encrypted, deduplicated, versioned.
# Why the Drive only, and the FUSE-in-paths trap that broke it 3 times: docs/notes/restic.md
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
  # /mnt/backup, owned by the USER: a FUSE mount is private to whoever mounted it.
  # It lives outside the home so it cannot enter `paths` and break the backup.
  systemd.tmpfiles.rules = [
    "d /mnt/backup 0755 v1cferr users -" # the home repo, on the Drive
  ];

  systemd.services.restic-backups-home-gdrive = {
    # mkAfter: the module puts ONLY ssh on the PATH, and the rclone: backend EXECUTES rclone.
    path = lib.mkAfter [ pkgs.rclone ];

    # A WRITABLE COPY: as root, rclone persists the renewed token OVER the file and the secret
    # is reborn root:users, breaking every consumer that runs as the USER.
    environment.RCLONE_CONFIG = "${runtimeDir}/rclone.conf";
    # mkBefore: `initialize = true` prepends a command that already talks to the Drive.
    preStart = lib.mkBefore ''
      install -m600 ${config.sops.secrets.rclone_gdrive_conf.path} ${runtimeDir}/rclone.conf
    '';
  };

  services.restic.backups.home-gdrive = {
    # `rclone:<remote>:<path>`: restic starts an `rclone rcd` and talks HTTP with it. The path
    # names the MACHINE (the EX-B560M-V5 board) so it can coexist with other backups there.
    repository = "rclone:gdrive:BACKUPS_EX-B560M-V5/HOME";

    passwordFile = config.sops.secrets.restic_password.path;

    # NEVER the `rcloneConfig` attrset: it leaks the token into the world-readable store.

    initialize = true; # creates the repo on the 1st backup

    paths = [ "/home/v1cferr" ];

    # excludes what is regenerable (cache, builds, garbage). Zen's `storage` (site data) is NOT
    # cache, so it stays; only cache2 (the Firefox/Zen http cache) goes.
    exclude = [
      # Somebody else's FUSE: root cannot lstat it, restic exits 3 and the prune never runs.
      # --one-file-system does NOT save you: it still lstats the mount point.
      "/home/v1cferr/FAI-workstation"

      # The same trap, and permanent: ~/Drive mounts every boot, so the prune stopped for good.
      # A new user mount in /home enters this list in the SAME commit that creates it.
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
      # Pack size decides VIABILITY: on the Drive the cost is per API call, and there are 255k files.
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
      # A prune ceiling: repacking downloads and reuploads, so with none a bad prune is hours.
      "--max-repack-size=2G"
    ];

    # No --read-data-subset: rereading means DOWNLOADING ~2.4 GiB every day, forever.
    # The full read is manual: `sudo restic-home-gdrive check --read-data`.
    checkOpts = [ ];
  };
}
