# ═══════════════════════════════════════════════════════════════════════════
# DISK HYGIENE: a free space alarm plus trash expiry.
#
# WHY THIS EXISTS, and why it is NOT more GC: the Nix GC is already automatic
# (system/core/core.nix) and it works, but MEASURED on 30/07 it covers 9% of the disk, since
# /nix/store held 58 GiB against 626 GiB used. The other 91% is games and media (Bottles
# 319 GiB, Jellyfin 132, Games 47, Steam 8), and NONE of that can be deleted automatically:
# nobody should delete somebody's game on their own. So the right answer to "do not let the
# disk fill up" is not deleting more, it is WARNING with enough data for me to decide.
#
# TWO THINGS of different natures, together because they are the same task (keeping the disk
# under control) and both are user timers:
#   • disk-watch   -> the alarm: it notifies when free space drops, ALREADY WITH the biggest
#                     consumers in the message (the request was "to evaluate what I want to
#                     remove", and for that the notification has to say WHAT grew).
#   • trash-expire -> the trash was the only REAL garbage found in the measurement: 1.7 GiB
#                     sitting there, which nobody expired and which restic already excludes
#                     from the backup (restic.nix), so it was pure waste.
#
# THE DESIGN of the alarm (the reason it has two phases): `du` over the whole tree takes
# MINUTES on this machine (measured). Running that every 30 min would be absurd. So the timer
# only does the CHEAP check (`df`, instant) and the EXPENSIVE sweep only happens when the disk
# is actually low, which is the moment when spending a few minutes is exactly what you want.
# `nice` plus `ionice` so it does not compete with the session.
#
# ANTI-SPAM: a notification repeating every 30 min becomes noise and starts being ignored, the
# same mistake as my timers that drowned the journal (see bb8690c). It re-warns at most once
# every 12h per severity, but IMMEDIATELY if the severity goes up (warn to crit). The state
# lives in $XDG_RUNTIME_DIR, which resets at boot.
#
# THE OWNER (rule 15): a systemd --user timer, tied to graphical-session, because it needs the
# session, since what delivers the notification is Quickshell (the
# org.freedesktop.Notifications daemon).
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.disk;

  # The list of paths as shell arguments, already quoted.
  watchArgs = lib.escapeShellArgs cfg.watchPaths;

  diskWatch = pkgs.writeShellApplication {
    name = "disk-watch";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
      util-linux
      gnused
      gawk
    ];
    text = ''
      # --- phase 1: the cheap check ---------------------------------------
      # `df --output=avail -BG` comes out as "  123G", so strip the G and the space.
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

      # --- anti-spam ------------------------------------------------------
      now="$(date +%s)"
      if [ -f "$state" ]; then
        read -r last_sev last_ts < "$state" || true
        # the same severity and less than 12h ago means stay quiet. A severity that WENT UP
        # gets through.
        if [ "$last_sev" = "$sev" ] && [ "$((now - last_ts))" -lt 43200 ]; then
          exit 0
        fi
      fi

      # --- phase 2: the EXPENSIVE sweep, only now -------------------------
      # MiB so it can be sorted numerically; the output is formatted in GiB. `|| true`: a
      # nonexistent path or one without permission cannot take the alarm down.
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

  trashExpire = pkgs.writeShellApplication {
    name = "trash-expire";
    runtimeInputs = [ pkgs.trash-cli ];
    text = ''
      # -f means do not ask (the default only asks with -i, but in a timer it is better to be
      # explicit: a unit waiting for an answer hangs forever).
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
    # ── THE PANEL: the thresholds and what to measure ──────────────────────
    # 100/40 GiB and not a percentage: what matters is whether the NEXT game or patch fits, and
    # that is an absolute number. (There are 915 G in total here; on 30/07 there were 243 GiB
    # free, so 100 warns with real room to decide.)
    my.disk = {
      warnFreeGiB = 100;
      critFreeGiB = 40;
      # The weights measured on 30/07, from largest to smallest. It is deliberately NOT a full
      # `du /`: sweeping everything would take extra minutes and bring noise (/proc, /sys,
      # network mounts). If a new consumer shows up outside this list, it is 1 line here, and
      # filelight and czkawka exist precisely to discover it.
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

    # ── The space alarm ────────────────────────────────────────────────────
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
        # The script already exits silently when there is nothing to say; this cuts the
        # "Starting…/Finished…" that SYSTEMD logs on its own, the lesson of bb8690c, where two
        # timers of mine added up to 2148 lines/day in the journal.
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

    # ── Trash expiry ───────────────────────────────────────────────────────
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
