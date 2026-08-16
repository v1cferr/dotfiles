# BTRFS: filesystem integrity and maintenance (the SSOT of btrfs POLICY).
#
# The division of labor, so nobody looks in the wrong place:
#   • LAYOUT (subvolumes, mount options)   -> hosts/<host>/disko.nix
#   • POLICY (scrub, alarm, reclaim, …)    -> HERE
#   • SNAPSHOTS (retention, schedule)      -> system/services/btrbk.nix
#
# Machine-agnostic on purpose (it lives in system/, not in hosts/): everything here is behind
# the `is the root btrfs?` guard, so a future ext4 host simply receives none of it, instead of
# breaking with a scrub unit pointing at a filesystem that has no checksums.
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  lib,
  pkgs,
  utils,
  ...
}:

let
  rootIsBtrfs = config.fileSystems ? "/" && config.fileSystems."/".fsType == "btrfs";

  # The autoScrub module names the unit with the ESCAPED path ("/" becomes "-", hence
  # "btrfs-scrub--"). Deriving it instead of writing the name by hand: if the scrub's target
  # changes, the onFailure follows instead of pointing at a nonexistent unit.
  scrubUnit = "btrfs-scrub-${utils.escapeSystemdPath "/"}";

  # The machine's real users (an SSOT: it comes from users.users, not from a literal). It is the
  # list of sessions that can receive the alarm's bubble below.
  normalUsers = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);

  # ── THE ALARM ─────────────────────────────────────────────────────────────
  # A checksum error is the most expensive information this filesystem produces, and the one
  # that least forgives delay, so it goes out through TWO channels, in this order:
  #   1. the journal (@log, its own subvolume), which survives nobody being logged in;
  #   2. a critical notification (it stays on screen and does not disappear on its own) in
  #      EVERY live session.
  # Channel 2 is what you see; channel 1 is what guarantees the message existed.
  #
  # runuser plus DBUS_SESSION_BUS_ADDRESS because what delivers notifications here is
  # Quickshell, which runs in the user's session, and a system unit does not talk to it without
  # entering the right bus.
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

      # An array (and not `for u in <list>`) because Nix may generate a SINGLE name, and then
      # the writeShellApplication shellcheck complains about a loop that runs once.
      users=( ${lib.escapeShellArgs normalUsers} )
      for u in "''${users[@]}"; do
        uid="$(id -u "$u" 2>/dev/null)" || continue
        bus="/run/user/$uid/bus"
        [ -S "$bus" ] || continue   # no live session, so only the journal, and that is fine
        # The ABSOLUTE path of notify-send: runuser can rebuild the PATH when switching users,
        # and then the libnotify binary would fall out of reach.
        runuser -u "$u" -- env "DBUS_SESSION_BUS_ADDRESS=unix:path=$bus" \
          ${pkgs.libnotify}/bin/notify-send -a "btrfs" -u critical \
          -i drive-harddisk "$title" "$body" || true
      done
    '';
  };
in
lib.mkIf rootIsBtrfs {
  # ═══ SCRUB: rereads EVERY block and checks the checksum ════════════════════
  # Without a scrub the checksum only reports an error when you happen to read the rotten
  # sector, which is to say on the day the file matters. On ext4 that did not even exist.
  # ONE target is enough: a scrub is per FILESYSTEM, not per subvolume, so "/" already covers
  # @home, @nix, @persist and @log, which are the same /dev/nvme0n1p2.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # `btrfs scrub start -B` exits non-zero when it finds an error (correctable or not), and it
  # is that exit that becomes the alarm. BEFORE this, the scrub ran and failed silently, and a
  # scrub nobody reads is the same as a scrub turned off.
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

  # ═══ ERROR COUNTERS: the watchman between one scrub and the next ═══════════
  # The scrub is monthly; an NVMe that starts failing on day 2 would go 28 days with no
  # warning. These counters are persistent and go up on EVERY bad I/O (read, write, flush,
  # corruption, generation), so checking them is cheap and catches the problem early.
  # `-c` means it exits non-zero if any counter is different from zero.
  #
  # A counter does not reset itself: after investigating, acknowledge it with
  # `sudo btrfs device stats -z /`, otherwise the alarm (correctly) repeats every day.
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

  # ═══ AUTOMATIC BLOCK GROUP RECLAIM (it replaces the periodic balance) ══════
  # The classic btrfs footgun: it allocates block groups for data and metadata and does not
  # give them back when they empty, so the disk becomes "full" (ENOSPC) with free space showing
  # in df. The old recipe was a `btrfs balance -dusage=N` cron (btrfsmaintenance). Since kernel
  # 6.11 that is a KERNEL FEATURE, and the kernel knows something the cron does not: when
  # relocating is NOT worth it.
  #   • dynamic_reclaim=1 makes the threshold stop being fixed and become computed (a target of
  #     10 unallocated block groups, with aggressiveness proportional to the pressure). It
  #     relocates ~nothing with the disk roomy, which is the case today (49%).
  #   • periodic_reclaim=1 makes the cleaner thread sweep from time to time and mark the
  #     candidates.
  # Writing to bg_reclaim_threshold would be EINVAL with dynamic_reclaim on (they are mutually
  # exclusive in the kernel), which is why we do not touch it.
  #
  # Data and metadata only: the `system` block group is tiny and relocating it is risk with no
  # return. The manual escape hatch still exists: `btrfs balance start -dusage=10 /`.
  systemd.services.btrfs-reclaim-tuning = {
    description = "Turns automatic block group reclaim on (dynamic plus periodic)";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # A loop over every mounted btrfs: the */allocation glob does not match
    # /sys/fs/btrfs/features, and a hardcoded UUID here would be a literal duplicated from disko
    # (rule 11). `|| true` because a kernel without the feature cannot take the boot down.
    script = ''
      for alloc in /sys/fs/btrfs/*/allocation; do
        for kind in data metadata; do
          echo 1 > "$alloc/$kind/dynamic_reclaim"  || true
          echo 1 > "$alloc/$kind/periodic_reclaim" || true
        done
      done
    '';
  };

  # ═══ TRIM: one, not two ═══════════════════════════════════════════════════
  # Since kernel 6.2 btrfs turns `discard=async` on by itself on an SSD that supports it, and
  # disko now declares it EXPLICITLY (not depending on a kernel default is what makes turning
  # the timer off safe). Async discard IS the same operation as fstrim, only queued by btrfs as
  # extents are freed, with a rate limit. Keeping fstrim.timer alongside it means re-TRIMming in
  # a weekly burst ranges that were already trimmed: duplicated work, with no gain.
  # If discard=async ever leaves disko, TURN THIS BACK ON in the same commit.
  services.fstrim.enable = false;

  # ═══ NOCOW on the databases ═══════════════════════════════════════════════
  # CoW plus random 8 KiB writes (which is what a database does) equals fragmentation that only
  # gets worse. A `+C` on the DIRECTORY makes every NEW file be born nodatacow.
  #
  # TWO honest warnings:
  #   • A file that ALREADY exists is not converted (chattr +C fails on a file with extents).
  #     Converting for real requires copying into a new directory that already has +C and
  #     swapping, which is too invasive to automate here, and the gain at these databases'
  #     current size does not pay for the risk.
  #   • nodatacow also turns the CHECKSUM off for those files. It is a conscious trade-off:
  #     Postgres has its own checksums, and Jellyfin's SQLite is rebuildable by scanning the
  #     library again.
  systemd.tmpfiles.rules = [
    "h /var/lib/docker/volumes - - - - +C" # container volumes (duo's Postgres lives here)
    "h /var/lib/jellyfin/data  - - - - +C" # the Jellyfin library's SQLite
  ];
}
