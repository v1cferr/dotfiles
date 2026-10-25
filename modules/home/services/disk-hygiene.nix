# DISK HYGIENE: a free-space alarm that names the biggest consumers, plus trash expiry.
# Why warning beats deleting, and the 2-phase design: docs/notes/boot-and-storage/disk-hygiene.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    coreutils
    findutils
    gawk
    gnused
    libnotify
    notify
    trash-cli
    util-linux
    uv
    writeShellApplication
    ;

  cfg = config.my.disk;

  # The list of paths as shell arguments, already quoted.
  watchArgs = lib.escapeShellArgs cfg.watchPaths;

  diskWatch = writeShellApplication {
    name = "disk-watch";
    runtimeInputs = [
      coreutils
      findutils
      libnotify
      notify
      util-linux
      gnused
      gawk
    ];
    text = ''
            # phase 1: the cheap check. `df --output=avail -BG` prints "  123G", so strip it down.
            free="$(df --output=avail -BG ${lib.escapeShellArg cfg.filesystem} | tail -1 | tr -dc '0-9')"
            [ -n "$free" ] || exit 0   # df failed (the fs disappeared?), so do not invent an alarm

            if   [ "$free" -lt ${toString cfg.critFreeGiB} ]; then sev=crit
            elif [ "$free" -lt ${toString cfg.warnFreeGiB} ]; then sev=warn
            else sev=ok
            fi

            state="''${XDG_RUNTIME_DIR:-/tmp}/disk-watch.state"
            if [ "$sev" = ok ]; then
              rm -f "$state"   # back to normal, so the next squeeze warns immediately
              exit 0
            fi

            # anti-spam: 12h per severity, but a severity that WENT UP gets through immediately.
            now="$(date +%s)"
            if [ -f "$state" ]; then
              read -r last_sev last_ts < "$state" || true
              # the same severity and less than 12h ago means stay quiet. A severity that WENT UP
              # gets through.
              if [ "$last_sev" = "$sev" ] && [ "$((now - last_ts))" -lt 43200 ]; then
                exit 0
              fi
            fi

            # phase 2: the EXPENSIVE sweep, only now. MiB so it sorts numerically; `|| true` because an
            # unreadable path cannot take the alarm down. `-F'\t'` and not the default split: du
            # separates with a TAB, and a path with spaces (every Windows game has them) loses its tail
            # to whitespace splitting. ONE du feeds both the ranking and the growth line below.
            sizes="$(nice -n 19 ionice -c 3 du -sx --block-size=1M ${watchArgs} 2>/dev/null || true)"

            dirs="$(
              printf '%s\n' "$sizes" \
                | sort -rn \
                | head -n ${toString cfg.topN} \
                | awk -F'\t' -v home="$HOME" 'NF == 2 {
                    path = $2
                    sub("^" home, "~", path)
                    printf "%6.1f GiB  %s\n", $1 / 1024, path
                  }' || true
            )"

            # WHAT GREW: the ranking says what is big, which after a month is the same answer every
            # time. The live sizes against the last weekly snapshot say what CHANGED, which is the
            # thing to act on. Same awk as disk-report, so the two never disagree.
            trend=${lib.escapeShellArg cfg.trendFile}
            grew=""
            if [ -f "$trend" ]; then
              last_date="$(tail -n 1 "$trend" | cut -f1)"
              grew="$(
                {
                  awk -F'\t' -v d="$last_date" '$1 == d' "$trend"
                  printf '%s\n' "$sizes" | awk -F'\t' 'NF == 2 { print "now\t" $1 "\t" $2 }'
                } | awk -v min=1 -f ${./scripts/disk-growth.awk} \
                  | sort -gr \
                  | head -n 3 \
                  | sed "s|$HOME|~|" || true
              )"
            fi

            # SNAPSHOT-HELD SPACE is invisible to every du above. When `df` used outruns what the
            # list adds up to by a lot, the likeliest owner is data only the btrbk snapshots still
            # reference, and btdu is the one tool that can show it.
            used="$(df --output=used -BG ${lib.escapeShellArg cfg.filesystem} | tail -1 | tr -dc '0-9')"
            listed="$(printf '%s\n' "$sizes" | awk -F'\t' '{ s += $1 } END { printf "%d", s / 1024 }')"
            hint=""
            if [ -n "$used" ] && [ "$((used - listed))" -gt ${toString cfg.unlistedGiB} ]; then
              hint="$((used - listed)) GiB used is outside this list, likely held by snapshots: sudo btdu /"
            fi

            # The directory ranking answers WHERE and stops there. MEASURED on 30/08: Downloads showed up
            # at 34.9 GiB and 17.4 of those were ONE .rar. The folder is not the thing you delete, so the
            # alarm names the file too.
            files="$(
              nice -n 19 ionice -c 3 find "$HOME" -xdev -type f -size +${toString cfg.bigFileGiB}G \
                -printf '%s\t%p\n' 2>/dev/null \
                | sort -rn \
                | head -n ${toString cfg.alarmTopFiles} \
                | awk -F'\t' -v home="$HOME" '{
                    path = $2
                    sub("^" home, "~", path)
                    printf "%6.1f GiB  %s\n", $1 / 1073741824, path
                  }' || true
            )"

            body="$dirs"
            if [ -n "$grew" ]; then
              body="$body

      Grew since $last_date:
      $grew"
            fi
            if [ -n "$files" ]; then
              body="$body

      Biggest files:
      $files"
            fi
            if [ -n "$hint" ]; then
              body="$body

      $hint"
            fi

            case "$sev" in
              crit) urgency=critical; priority=urgent; title="Disk critical, $free GiB free" ;;
              *)    urgency=normal;   priority=high;   title="Disk low, $free GiB free" ;;
            esac

            notify-send -a "Disk" -u "$urgency" -i drive-harddisk \
              "$title" "$body" || true
            # The PHONE too: a desktop bubble at 125 GiB free went unseen while the disk filled. The
            # anti-spam above already throttles both. `notify` exits 0 without its secret.
            notify -p "$priority" -T floppy_disk "$title" "$body" || true

            printf '%s %s\n' "$sev" "$now" > "$state"
    '';
  };

  # The caches with an OWNER. Everything reclaimable in ~/.cache that is safe to touch turned out
  # to be exactly this one, and the two obvious generic approaches are both wrong here:
  #
  # `-atime`: the filesystem is mounted `noatime` (`hosts/ex-b560m-v5/disko.nix`), so every
  # access time in there is frozen at the day the file landed on this disk. An age-by-access rule
  # would sweep the whole cache or none of it, and neither answer means anything.
  #
  # `-mtime -delete`: `~/.cache/nix/tarball-cache-v2` is 1.2 GiB and is a bare GIT OBJECT STORE
  # (`objects/`, `refs/`, `HEAD`). Deleting loose objects out of it by age corrupts the cache
  # rather than trimming it, and nix would not notice until a flake input failed to resolve.
  #
  # So it prunes through the tool that knows what is still referenced. MEASURED on 30/08: 23230
  # files and 1.1 GiB on the first run.
  cacheExpire = writeShellApplication {
    name = "cache-expire";
    runtimeInputs = [ uv ];
    text = ''
      # No --force: that flag ignores the in-use check, and a prune racing a live `uv` would pull
      # wheels out from under it.
      #
      # A prune that cannot get the lock is a NO-OP and NEVER a failure. MEASURED on 30/08: an
      # ad-hoc `uv run ... serve` held the cache lock and the default 300 s wait ended in exit 2.
      # A unit that goes red to say "somebody was building, try next week" teaches you to ignore
      # red units, and 60 s is already long enough for anything that is merely passing through.
      export UV_LOCK_TIMEOUT=60
      uv cache prune || echo "cache in use, skipping this run" >&2
    '';
  };

  trashExpire = writeShellApplication {
    name = "trash-expire";
    runtimeInputs = [ trash-cli ];
    text = ''
      # -f: a unit waiting for an answer hangs forever, so never leave it implicit.
      trash-empty -f ${toString cfg.trashDays}
    '';
  };
in
{
  options.my.disk = {
    filesystem = lib.mkOption {
      type = lib.types.str;
      default = "/";
      description = "The filesystem watched by the alarm (df).";
    };
    warnFreeGiB = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "Below this, it notifies (normal urgency).";
    };
    critFreeGiB = lib.mkOption {
      type = lib.types.int;
      default = 40;
      description = "Below this, it notifies as critical (it stays on screen).";
    };
    topN = lib.mkOption {
      type = lib.types.int;
      default = 6;
      description = "How many top consumers to list in the notification.";
    };
    alarmTopFiles = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "How many individual files the notification names. `bigFileGiB` sets the floor.";
    };
    trashDays = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Age in days for the trash to expire on its own.";
    };
    unlistedGiB = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "Used space outside watchPaths beyond which the alarm points at btdu.";
    };
    watchPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "The paths measured when the alarm fires (the usual heavy suspects).";
    };
  };

  config = {
    # THE PANEL. Absolute GiB and NOT a percentage: what matters is whether the next game fits.
    # 150 and not the old 100: the biggest single consumer here is now a ~88 GiB game, so 100 GiB
    # free is barely one install of headroom, which is too late to still be a CHOICE.
    my.disk = {
      warnFreeGiB = 150;
      critFreeGiB = 40;
      # The weights REMEASURED on 24/10/2026, when the disk hit 87% and this list was missing the
      # VM and Darling that had filled it. Deliberately not a full `du /`, which would add minutes
      # and noise; a new consumer is 1 line here. Siblings only: du drops a path nested under
      # another one passed in the same run, so a child of a listed path would vanish silently.
      #
      # `/mnt/windows/Games` is deliberately NOT in this list. This ranking exists to explain why
      # the ROOT filesystem is full, and a different disk in it would be an answer to a question
      # nobody asked. The games disk is covered by the trend log and disk-report instead.
      watchPaths = [
        "/nix/store" # 51 GiB after the 24/10 GC (156 before), handled by the GC (core.nix), not deletable by hand
        "/srv/media" # 108 GiB, the Jellyfin library
        "${config.home.homeDirectory}/Projects" # 51 GiB, the macOS lab VM images deleted on 24/10
        "${config.home.homeDirectory}/.local/share/Steam" # 21 GiB, the library is in @home (its own subvolume)
        "${config.home.homeDirectory}/Downloads" # 33 GiB
        "${config.home.homeDirectory}/.config" # 28 GiB, which a config dir has no business being
        "${config.home.homeDirectory}/.cache" # 18 GiB
        "${config.home.homeDirectory}/.local/share/bottles" # 17 GiB, the Wine prefixes
        "${config.home.homeDirectory}/Documents" # 4.5 GiB
        "${config.home.homeDirectory}/Games" # 1.8 GiB
        "${config.home.homeDirectory}/.local/share/Trash" # ~0 (it expires on its own, below)
      ];
    };

    home.packages = [
      diskWatch
      cacheExpire
      trashExpire
    ];

    # The space alarm.
    systemd.user.services.disk-watch = {
      Unit = {
        Description = "Disk space alarm (it notifies with the biggest consumers)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        StartLimitIntervalSec = 3600;
        StartLimitBurst = 5;
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${diskWatch}/bin/disk-watch";
        # The script is silent when there is nothing to say; this cuts SYSTEMD's own per-trigger lines.
        LogLevelMax = "warning";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    systemd.user.timers.disk-watch = {
      Unit.Description = "Periodic disk space check";
      Timer = {
        OnActiveSec = "2min"; # gives the session time to come up before the 1st check
        OnUnitActiveSec = "30min";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    # Cache expiry. WEEKLY and not daily: unlike the trash, a pruned cache costs a redownload on
    # the next build, so there is no point paying that every day for a ~1 GiB drip.
    systemd.user.services.cache-expire = {
      Unit.Description = "Prunes the unreachable objects out of the uv cache";
      Service = {
        Type = "oneshot";
        ExecStart = "${cacheExpire}/bin/cache-expire";
        LogLevelMax = "warning";
      };
    };

    systemd.user.timers.cache-expire = {
      Unit.Description = "Weekly cache prune";
      Timer = {
        OnCalendar = "Sun 05:15"; # ahead of the 05:30 trend snapshot, so it measures the result
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };

    # Trash expiry.
    systemd.user.services.trash-expire = {
      Unit.Description = "Expires trash items older than ${toString cfg.trashDays} days";
      Service = {
        Type = "oneshot";
        ExecStart = "${trashExpire}/bin/trash-expire";
        LogLevelMax = "warning";
      };
    };

    systemd.user.timers.trash-expire = {
      Unit.Description = "Daily trash expiry";
      Timer = {
        OnCalendar = "daily";
        Persistent = true; # machine off at the scheduled time means it runs on the next boot
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
