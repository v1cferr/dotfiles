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
    gawk
    gnused
    libnotify
    trash-cli
    util-linux
    writeShellApplication
    ;

  cfg = config.my.disk;

  # The list of paths as shell arguments, already quoted.
  watchArgs = lib.escapeShellArgs cfg.watchPaths;

  diskWatch = writeShellApplication {
    name = "disk-watch";
    runtimeInputs = [
      coreutils
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
      # unreadable path cannot take the alarm down.
      body="$(
        nice -n 19 ionice -c 3 du -sx --block-size=1M ${watchArgs} 2>/dev/null \
          | sort -rn \
          | head -n ${toString cfg.topN} \
          | awk -v home="$HOME" '{
              size = $1 / 1024
              $1 = ""
              sub(/^ /, "")
              path = $0
              sub("^" home, "~", path)
              printf "%6.1f GiB  %s\n", size, path
            }' || true
      )"

      case "$sev" in
        crit) urgency=critical; title="Disk critical, $free GiB free" ;;
        *)    urgency=normal;   title="Disk low, $free GiB free" ;;
      esac

      notify-send -a "Disk" -u "$urgency" -i drive-harddisk \
        "$title" "$body" || true

      printf '%s %s\n' "$sev" "$now" > "$state"
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
      default = 5;
      description = "How many top consumers to list in the notification.";
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
    # THE PANEL. 100/40 GiB and NOT a percentage: what matters is whether the next game fits.
    my.disk = {
      warnFreeGiB = 100;
      critFreeGiB = 40;
      # The weights measured on 30/07. Deliberately not a full `du /`, which would add minutes and
      # noise; a new consumer is 1 line here, and filelight/czkawka exist to discover it.
      watchPaths = [
        "${config.home.homeDirectory}/.local/share/bottles" # 319 GiB (Wine/Bottles: Battlenet, CS-II, Ascension)
        "/srv/media" # 132 GiB, the Jellyfin library
        "${config.home.homeDirectory}/Games" # 47 GiB
        "/nix/store" # 58 GiB, handled by the GC (core.nix), not deletable by hand
        "${config.home.homeDirectory}/.local/share/Steam" # 8 GiB
        "${config.home.homeDirectory}/.cache" # 3.9 GiB
        "${config.home.homeDirectory}/Downloads" # 2.5 GiB
        "${config.home.homeDirectory}/.local/share/Trash" # 1.7 GiB (it expires on its own, below)
      ];
    };

    home.packages = [
      diskWatch
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
