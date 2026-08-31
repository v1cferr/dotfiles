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
            # to whitespace splitting.
            dirs="$(
              nice -n 19 ionice -c 3 du -sx --block-size=1M ${watchArgs} 2>/dev/null \
                | sort -rn \
                | head -n ${toString cfg.topN} \
                | awk -F'\t' -v home="$HOME" '{
                    path = $2
                    sub("^" home, "~", path)
                    printf "%6.1f GiB  %s\n", $1 / 1024, path
                  }' || true
            )"

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
            if [ -n "$files" ]; then
              body="$body

      Biggest files:
      $files"
            fi

            case "$sev" in
              crit) urgency=critical; title="Disk critical, $free GiB free" ;;
              *)    urgency=normal;   title="Disk low, $free GiB free" ;;
            esac

            notify-send -a "Disk" -u "$urgency" -i drive-harddisk \
              "$title" "$body" || true

            printf '%s %s\n' "$sev" "$now" > "$state"
    '';
  };

  # The caches with an OWNER. Everything reclaimable in ~/.cache that is safe to touch turned out
  # to be exactly this one, and the two obvious generic approaches are both wrong here:
  #
  # `-atime`: the filesystem is mounted `noatime` (`hosts/nixos-kingston/disko.nix`), so every
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
      # The weights REMEASURED on 30/08 (the 30/07 list had drifted badly: /srv/media was 3x off
      # and the 4th biggest consumer was not even here). Deliberately not a full `du /`, which
      # would add minutes and noise; a new consumer is 1 line here.
      watchPaths = [
        "${config.home.homeDirectory}/.local/share/bottles" # 316 GiB (Wine/Bottles: Battlenet, CS-II, Ascension)
        "${config.home.homeDirectory}/Games" # 46 GiB
        "/nix/store" # 46 GiB, handled by the GC (core.nix), not deletable by hand
        "/srv/media" # 45 GiB, the Jellyfin library
        "${config.home.homeDirectory}/Downloads" # 35 GiB, and it was 2.5 a month earlier
        "${config.home.homeDirectory}/.config" # 27 GiB, which a config dir has no business being
        "${config.home.homeDirectory}/Projects" # 18 GiB
        "${config.home.homeDirectory}/.cache" # 9 GiB
        "${config.home.homeDirectory}/.local/share/Steam" # 8 GiB
        "${config.home.homeDirectory}/Documents" # 4.5 GiB
        "${config.home.homeDirectory}/.local/share/Trash" # 0.1 GiB (it expires on its own, below)
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
