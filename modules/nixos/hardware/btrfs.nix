# BTRFS: the SSOT of btrfs POLICY (scrub, alarm, reclaim, trim, nocow). The LAYOUT is disko's and
# the SNAPSHOTS are btrbk's. Every decision, measured: docs/notes/boot-and-storage/btrfs.md
{
  config,
  lib,
  pkgs,
  utils,
  ...
}:

let
  inherit (pkgs) btrfs-progs;

  rootIsBtrfs = config.fileSystems ? "/" && config.fileSystems."/".fsType == "btrfs";

  # The backup disk is btrfs too and holds the only other copy, so it gets the same scrub. Its
  # path is restic's option (rule 11), and the fsType check keeps a non-btrfs disk out.
  backupMount = config.my.backup.mountPoint;
  backupIsBtrfs =
    config.my.services.restic
    && config.fileSystems ? ${backupMount}
    && config.fileSystems.${backupMount}.fsType == "btrfs";

  lostData =
    if config.my.services.restic then
      "restic on the backup disk is where to restore it from"
    else
      "there is NO off-disk backup to restore it from";

  # Per target: what an uncorrectable error MEANS there, which is the part the alarm must say.
  scrubTargets = {
    "/" = "the affected data is lost in this copy, and ${lostData}";
  }
  // lib.optionalAttrs backupIsBtrfs {
    ${backupMount} =
      "the BACKUP copy is damaged (the live data on the NVMe is fine). Run 'sudo restic check --read-data' on the repo, and replace the disk if the errors grow";
  };

  # The unit names are DERIVED, not typed: if a scrub target changes, its onFailure follows.
  escape = utils.escapeSystemdPath;

  # `scrub start -B` exits non-zero on an error, and that exit is the alarm. Before this the
  # scrub failed SILENTLY, which is the same as a scrub turned off.
  scrubAlarms = lib.concatMapAttrs (fs: meaning: {
    "btrfs-scrub-${escape fs}".onFailure = [ "btrfs-alert-scrub-${escape fs}.service" ];

    "btrfs-alert-scrub-${escape fs}" = {
      description = "Alarm: the btrfs scrub of ${fs} found an error";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''
          ${lib.getExe config.my.alert} btrfs drive-harddisk \
            "btrfs: error in the scrub of ${fs}" \
            "The monthly scrub failed. Run 'sudo btrfs scrub status ${fs}' and 'sudo btrfs device stats ${fs}'. If there is an uncorrectable error, ${meaning}."
        '';
      };
    };
  }) scrubTargets;
in
lib.mkIf rootIsBtrfs (
  lib.mkMerge [
    { systemd.services = scrubAlarms; }
    {
      # SCRUB. A scrub is per FILESYSTEM, so "/" already covers @home, @nix, @persist and @log. The
      # backup disk is automounted, so the scrub's own access wakes it.
      services.btrfs.autoScrub = {
        enable = true;
        interval = "monthly";
        fileSystems = lib.attrNames scrubTargets;
      };

      # ERROR COUNTERS: the daily watchman between one monthly scrub and the next. They do not reset
      # themselves, so acknowledge with `btrfs device stats -z /` AFTER investigating.
      systemd.services.btrfs-device-stats = {
        description = "Checks the btrfs I/O error counters";
        onFailure = [ "btrfs-alert-devstats.service" ];
        serviceConfig = config.my.systemd.hardened // {
          Type = "oneshot";
          ExecStart = "${btrfs-progs}/bin/btrfs device stats -c /";
          LogLevelMax = "warning"; # does not log "Starting/Finished" every day (the bb8690c lesson)
        };
      };

      systemd.timers.btrfs-device-stats = {
        description = "Daily check of the btrfs error counters";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true; # machine off at the scheduled time means it runs on the next boot
          RandomizedDelaySec = "10min";
        };
      };

      systemd.services.btrfs-alert-devstats = {
        description = "Alarm: a btrfs I/O error counter is not zero";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''
            ${lib.getExe config.my.alert} btrfs drive-harddisk \
              "btrfs: an I/O error counter is not zero" \
              "The disk recorded a read, write or corruption error. See 'sudo btrfs device stats /' and the SMART data ('sudo smartctl -a /dev/nvme0'). Acknowledge with 'sudo btrfs device stats -z /' AFTER investigating."
          '';
        };
      };

      # AUTOMATIC BLOCK GROUP RECLAIM: a KERNEL feature since 6.11, and it replaces the old
      # `btrfs balance` cron. Why not bg_reclaim_threshold, and why data/metadata only: the notes.
      systemd.services.btrfs-reclaim-tuning = {
        description = "Turns automatic block group reclaim on (dynamic plus periodic)";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
        # Not ProtectKernelTunables: the whole point of this unit is writing /sys.
        serviceConfig = config.my.systemd.hardened // {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        # A loop, because the glob would catch /sys/fs/btrfs/features and a UUID here would duplicate
        # disko (rule 11). `|| true`: a kernel without the feature cannot take the boot down.
        script = ''
          for alloc in /sys/fs/btrfs/*/allocation; do
            for kind in data metadata; do
              echo 1 > "$alloc/$kind/dynamic_reclaim"  || true
              echo 1 > "$alloc/$kind/periodic_reclaim" || true
            done
          done
        '';
      };

      # TRIM: `discard=async` is declared in disko and IS the same operation, so fstrim would only
      # re-trim in a weekly burst. If it leaves disko, turn this back on in the SAME commit.
      services.fstrim.enable = false;

      # NOCOW on the databases: `+C` on the DIRECTORY, so only NEW files. It also turns the checksum
      # off for them, which is a conscious trade; see the notes before adding a path.
      systemd.tmpfiles.rules = [
        "h /var/lib/docker/volumes - - - - +C" # container volumes (duo's Postgres lives here)
        "h /var/lib/jellyfin/data  - - - - +C" # the Jellyfin library's SQLite
      ];
    }
  ]
)
