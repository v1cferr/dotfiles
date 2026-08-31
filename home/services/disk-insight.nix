# DISK INSIGHT: what GREW (a weekly trend log), what is NOT BEING USED (a /proc sampler) and the
# on-demand `disk-report`. Why sampling beats atime: docs/notes/boot-and-storage/disk-insight.md
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
    gnugrep
    util-linux
    writeShellApplication
    ;

  cfg = config.my.disk;

  # The state is DELIBERATELY not in ~/.cache: a cache is disposable, and losing it here resets
  # the "last used" history to zero, which is the one thing that cannot be recomputed.
  stateDir = "${config.xdg.stateHome}/disk-insight";

  usageArgs = lib.escapeShellArgs cfg.usagePaths;
  watchArgs = lib.escapeShellArgs cfg.watchPaths;
  ignoreArgs = lib.escapeShellArgs cfg.usageIgnoreCommands;
  launcherArgs = lib.escapeShellArgs cfg.usageLauncherCommands;

  # THE SAMPLER. It answers "did I RUN this", which is a different question from "was this file
  # read": an indexer or a backup pass touches files without the game ever being opened.
  usageSample = writeShellApplication {
    name = "disk-usage-sample";
    runtimeInputs = [
      coreutils
      gawk
      gnugrep
    ];
    text = ''
      state=${lib.escapeShellArg stateDir}
      last="$state/last-seen.tsv"
      paths=(${usageArgs})
      mkdir -p "$state"
      now="$(date +%s)"

      # One blob with every live process: the resolved exe, the cwd and the argv. The argv is what
      # makes this work for Wine: a bottle's game runs as a /nix/store wine binary, so the exe
      # never names the bottle and only the command line does.
      # MEASURED trap: a tool that merely NAMES a watched path in its argv is not the game running.
      # The hourly cs2-saves-backup rsync carries the CS2 bottle path, and disk-trend-snapshot's own
      # du carries every path there is. Counting those marks everything "used" forever, which is the
      # exact failure this sampler exists to prevent.
      ignore="$(printf '%s\n' ${ignoreArgs})"

      launchers="$(printf '%s\n' ${launcherArgs})"

      blob="$(
        for p in /proc/[0-9]*; do
          exe="$(readlink -f "$p/exe" 2>/dev/null || true)"
          base="''${exe##*/}"
          if [ -n "$exe" ] && printf '%s\n' "$ignore" | grep -qxF -- "$base"; then
            continue
          fi
          # exe and cwd are EVIDENCE: a process cannot run from a path or sit in it by accident.
          printf '%s\n' "$exe"
          readlink -f "$p/cwd" 2>/dev/null || true
          # argv is only a MENTION, so it counts for launchers alone. RPCS3 needs it (the ISO is
          # an argument and its exe lives in /nix/store), but reading it for every process would
          # make any shell that so much as types the path look like a game session.
          if printf '%s\n' "$launchers" | grep -qxF -- "$base"; then
            # The subshell contains the redirect: a pid that dies between the glob and the open
            # makes the SHELL print the error, not tr, so `2>/dev/null` has to wrap both.
            ( tr '\0' '\n' < "$p/cmdline" ) 2>/dev/null || true
          fi
        done
      )"

      # The hits of THIS run first, the previous state after: the awk keeps the FIRST line per
      # path, so a path that is not running right now holds the timestamp it already had.
      {
        for path in "''${paths[@]}"; do
          if printf '%s\n' "$blob" | grep -qF -- "$path"; then
            printf '%s\t%s\n' "$now" "$path"
          fi
        done
        if [ -f "$last" ]; then cat "$last"; fi
      } | awk -F'\t' '!seen[$2]++' > "$last.tmp"

      mv "$last.tmp" "$last"
    '';
  };

  # THE TREND. Append-only, one line per path per run, because the question it answers ("what grew
  # this month") needs history and a single current number cannot give it.
  trendSnapshot = writeShellApplication {
    name = "disk-trend-snapshot";
    runtimeInputs = [
      coreutils
      gawk
      util-linux
    ];
    text = ''
      state=${lib.escapeShellArg stateDir}
      mkdir -p "$state"
      stamp="$(date +%Y-%m-%d)"
      # nice/ionice: a full du competes with the session, and this one runs unattended.
      nice -n 19 ionice -c 3 du -sx --block-size=1M ${watchArgs} ${usageArgs} 2>/dev/null \
        | awk -F'\t' -v d="$stamp" '{ print d "\t" $1 "\t" $2 }' >> "$state/trend.tsv" || true
    '';
  };

  # THE REPORT. Everything the timers know, on demand, because the alarm only speaks when space is
  # already short and by then the useful question is not "how much" but "since when".
  diskReport = writeShellApplication {
    name = "disk-report";
    runtimeInputs = [
      coreutils
      findutils
      gawk
      gnugrep
      util-linux
    ];
    text = ''
      state=${lib.escapeShellArg stateDir}
      last="$state/last-seen.tsv"
      trend="$state/trend.tsv"
      now="$(date +%s)"

      echo "=== FREE SPACE ==="
      df -h ${lib.escapeShellArg cfg.filesystem}
      echo

      echo "=== BIGGEST DIRECTORIES ==="
      nice -n 19 ionice -c 3 du -sx --block-size=1M ${watchArgs} 2>/dev/null \
        | sort -rn \
        | awk -F'\t' '{ printf "%8.1f GiB  %s\n", $1/1024, $2 }' || true
      echo

      echo "=== LAST USED (only counts from the day the sampler was installed) ==="
      if [ -f "$last" ]; then
        nice -n 19 ionice -c 3 du -sx --block-size=1M ${usageArgs} 2>/dev/null \
          | sort -rn \
          | awk -F'\t' -v now="$now" -v lastfile="$last" '
              BEGIN {
                while ((getline line < lastfile) > 0) {
                  split(line, a, "\t"); seen[a[2]] = a[1]
                }
              }
              {
                n = split($2, parts, "/"); label = parts[n]
                if ($2 in seen) {
                  days = int((now - seen[$2]) / 86400)
                  when = (days == 0) ? "today" : days " days ago"
                } else {
                  when = "not once since sampling began"
                }
                printf "%8.1f GiB  %-24s %s\n", $1/1024, label, when
              }' || true
      else
        echo "  (the sampler has not run yet)"
      fi
      echo

      echo "=== BIGGEST FILES (over ${toString cfg.bigFileGiB} GiB) ==="
      find "$HOME" -xdev -type f -size +${toString cfg.bigFileGiB}G -printf '%s\t%p\n' 2>/dev/null \
        | sort -rn | head -n ${toString cfg.topFiles} \
        | awk -F'\t' '{ printf "%8.2f GiB  %s\n", $1/1073741824, $2 }' || true
      echo

      echo "=== GROWTH SINCE THE PREVIOUS SNAPSHOT ==="
      if [ -f "$trend" ]; then
        awk -F'\t' '
          { v[$3 SUBSEP $1] = $2; p[$3] = 1; if (!($1 in ds)) { ds[$1] = 1; o[++n] = $1 } }
          END {
            if (n < 2) { print "  (a single snapshot so far, no delta yet)"; exit }
            prev = o[n-1]; cur = o[n]
            for (path in p) {
              a = v[path SUBSEP cur]; b = v[path SUBSEP prev]
              if (a == "" || b == "") continue
              d = (a - b) / 1024
              if (d > 0.5 || d < -0.5) printf "%+8.1f GiB  %s\n", d, path
            }
          }
        ' "$trend" | sort -gr || true
      else
        echo "  (no trend log yet)"
      fi
      echo

      # Docker is not a runtimeInput on purpose: the engine is optional here (only the stacks turn
      # it on), so the report asks the PATH instead of pinning a dependency that may be off.
      if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        echo "=== DOCKER ==="
        docker system df
        echo
      fi

      echo "=== SNAPSHOTS ==="
      count="$(find /.snapshots -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
      echo "  $count btrbk snapshots of @home"
      echo "  their real cost needs root: sudo btrfs filesystem du -s /.snapshots/*"
    '';
  };
in
{
  options.my.disk = {
    usagePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "The paths the /proc sampler watches, at GAME granularity, not bucket.";
    };
    usageIgnoreCommands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Basenames whose process never counts as USE, only as a path mentioned.";
    };
    usageLauncherCommands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Basenames whose argv is trusted as use, not merely as a path mentioned.";
    };
    bigFileGiB = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "The floor for a file to show up in the report's biggest-files list.";
    };
    topFiles = lib.mkOption {
      type = lib.types.int;
      default = 15;
      description = "How many individual files the report lists.";
    };
    sampleMinutes = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = "The sampler's interval. Shorter than the shortest session worth counting.";
    };
    trendOnCalendar = lib.mkOption {
      type = lib.types.str;
      default = "Sun 05:30";
      description = "When the trend snapshot runs. After restic, nix-optimise and docker prune.";
    };
  };

  config = {
    # The sweepers and the copiers. They walk these paths BY DEFINITION, so a hit from one of
    # them says nothing about the game being played.
    my.disk.usageIgnoreCommands = [
      "du"
      "find"
      "rsync"
      "restic"
      "btrbk"
      "cp"
      "mv"
      "tar"
      "disk-report"
      "disk-trend-snapshot"
      "disk-usage-sample"
    ];

    # The launchers that name their target in the argv instead of running from it.
    my.disk.usageLauncherCommands = [
      "rpcs3"
      "wine"
      "wine64"
      "wine-preloader"
      "wine64-preloader"
      "wineserver"
      "steam"
      "bottles"
      "bottles-cli"
    ];

    # GAME granularity and not bucket: `bottles` as a whole is "used" the moment ANY game opens,
    # which is exactly the resolution that hides the one game nobody has touched in a month.
    my.disk.usagePaths =
      let
        bnet = "${config.home.homeDirectory}/.local/share/bottles/bottles/Battlenet/drive_c/Program Files (x86)";
        bottles = "${config.home.homeDirectory}/.local/share/bottles/bottles";
      in
      [
        "${bnet}/Diablo IV"
        "${bnet}/Overwatch"
        "${bnet}/Hearthstone"
        "${bottles}/Cities-Skylines-II"
        "${bottles}/Ascension"
        "${config.home.homeDirectory}/Games/PS3"
        "${config.home.homeDirectory}/.local/share/Steam/steamapps/common"
      ];

    home.packages = [
      usageSample
      trendSnapshot
      diskReport
    ];

    systemd.user.services.disk-usage-sample = {
      Unit = {
        Description = "Samples which watched paths have a live process";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${usageSample}/bin/disk-usage-sample";
        # Same reason as disk-watch: without this the per-trigger systemd lines alone flood the
        # journal, and this one fires 6x/hour.
        LogLevelMax = "warning";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    systemd.user.timers.disk-usage-sample = {
      Unit.Description = "Periodic usage sampling";
      Timer = {
        OnActiveSec = "1min";
        OnUnitActiveSec = "${toString cfg.sampleMinutes}min";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    systemd.user.services.disk-trend-snapshot = {
      Unit.Description = "Appends this week's sizes to the trend log";
      Service = {
        Type = "oneshot";
        ExecStart = "${trendSnapshot}/bin/disk-trend-snapshot";
        LogLevelMax = "warning";
      };
    };

    systemd.user.timers.disk-trend-snapshot = {
      Unit.Description = "Weekly disk trend snapshot";
      Timer = {
        OnCalendar = cfg.trendOnCalendar;
        Persistent = true; # the machine is off a lot, so a missed week runs on the next boot
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
