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
  rootIsBtrfs = config.fileSystems ? "/" && config.fileSystems."/".fsType == "btrfs";

  # The unit's name is DERIVED, not typed: if the scrub's target changes, the onFailure follows.
  scrubUnit = "btrfs-scrub-${utils.escapeSystemdPath "/"}";

  # The machine's real users (an SSOT from users.users, rule 11): who can get the bubble.
  normalUsers = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);

  # THE ALARM: the journal first (it survives nobody being logged in), then a critical bubble in
  # every live session. runuser + the session bus, because Quickshell is what delivers. Notes.
  btrfsAlert = pkgs.writeShellApplication {
    name = "btrfs-alert";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
      util-linux
    ];
    text = ''
      title="$1"
      body="$2"

      printf 'BTRFS ALERT: %s\n%s\n' "$title" "$body" >&2

      # An array, not `for u in <list>`: Nix may generate ONE name and shellcheck flags the loop.
      users=( ${lib.escapeShellArgs normalUsers} )
      for u in "''${users[@]}"; do
        uid="$(id -u "$u" 2>/dev/null)" || continue
        bus="/run/user/$uid/bus"
        [ -S "$bus" ] || continue   # no live session, so only the journal, and that is fine
        # The ABSOLUTE path: runuser can rebuild the PATH and libnotify would fall out of reach.
        runuser -u "$u" -- env "DBUS_SESSION_BUS_ADDRESS=unix:path=$bus" \
          ${pkgs.libnotify}/bin/notify-send -a "btrfs" -u critical \
          -i drive-harddisk "$title" "$body" || true
      done
    '';
  };
in
lib.mkIf rootIsBtrfs {
  # SCRUB. A scrub is per FILESYSTEM, so "/" already covers @home, @nix, @persist and @log.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # `scrub start -B` exits non-zero on an error, and that exit is the alarm. Before this the
  # scrub failed SILENTLY, which is the same as a scrub turned off.
  systemd.services.${scrubUnit}.onFailure = [ "btrfs-alert-scrub.service" ];

  systemd.services.btrfs-alert-scrub = {
    description = "Alarm: the btrfs scrub found an error";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''
        ${btrfsAlert}/bin/btrfs-alert \
          "btrfs: error in the scrub of /" \
          "The monthly scrub failed. Run 'sudo btrfs scrub status /' and 'sudo btrfs device stats /'. If there is an uncorrectable error, the affected data is lost in this copy, so restore it from restic."
      '';
    };
  };

  # ERROR COUNTERS: the daily watchman between one monthly scrub and the next. They do not reset
  # themselves, so acknowledge with `btrfs device stats -z /` AFTER investigating.
  systemd.services.btrfs-device-stats = {
    description = "Checks the btrfs I/O error counters";
    onFailure = [ "btrfs-alert-devstats.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.btrfs-progs}/bin/btrfs device stats -c /";
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
        ${btrfsAlert}/bin/btrfs-alert \
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
    serviceConfig = {
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
