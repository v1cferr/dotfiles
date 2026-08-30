# DROPBOX: ~/Dropbox synced (the Obsidian vault plus documents), as a USER service.
# The tray icon's cost, and the 10 days it spent syncing NOTHING: docs/notes/apps/dropbox.md
{
  config,
  inputs,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    buildFHSEnv
    coreutils
    dropbox
    dropbox-cli
    libnotify
    runCommand
    writeShellApplication
    ;

  enabled = osConfig.my.services.dropbox;

  # The session's browser, the SAME derivation home/packages.nix installs (rule 4).
  zen = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # nixpkgs hardcodes `export BROWSER=firefox` in the daemon's launcher and ships a whole
  # firefox-bin INSIDE the FHS sandbox, so the relink page opens in a browser that has never seen
  # this account and the flow dead-ends. Pointing it at the session's browser makes the daemon's
  # own relink one click. Measured on 25/08/2026, and detailed in the notes.
  dropboxFhs = dropbox.override {
    buildFHSEnv =
      args:
      buildFHSEnv (
        args
        // {
          # `--replace-fail` on purpose: a nixpkgs bump that touches this line BREAKS the build
          # instead of silently handing the browser back to Firefox.
          runScript = runCommand "install-and-start-dropbox" { } ''
            substitute ${args.runScript} "$out" \
              --replace-fail 'export BROWSER=firefox' 'export BROWSER=${lib.getExe' zen "zen-beta"}'
            chmod +x "$out"
          '';
          # With the browser outside the sandbox, firefox-bin is 316 MB of dead closure.
          targetPkgs = ps: lib.filter (p: (p.pname or "") != "firefox-bin") (args.targetPkgs ps);
        }
      );
  };

  # dropbox-cli takes the FHS package as an ARGUMENT, so the override has to reach it too:
  # otherwise the CLI would keep starting the stock daemon and the override would be decorative.
  dropboxCli = dropbox-cli.override { dropbox = dropboxFhs; };

  # The daemon runs with its OWN HOME, and the CLI only finds its socket with the SAME HOME: a
  # plain `dropbox status` LIES with the daemon alive. That lie is how the incident hid.
  dropboxHome = "${config.home.homeDirectory}/.dropbox-hm";
  dropboxCmd = lib.getExe' config.services.dropbox.package "dropbox";

  # The CLI with the right HOME. It references the module's SAME store path (rule 4).
  dropboxHm = writeShellApplication {
    name = "dropbox-hm";
    text = ''
      export HOME=${lib.escapeShellArg dropboxHome}
      exec ${dropboxCmd} "$@"
    '';
  };

  linkWatch = writeShellApplication {
    name = "dropbox-link-watch";
    runtimeInputs = [
      coreutils
      libnotify
    ];
    text = ''
          # `timeout` because the CLI BLOCKS on the daemon's socket, and a timer stuck waiting on a hung
          # daemon warns about nothing, which is the exact failure this script exists to cover.
          out="$(timeout 30 ${dropboxHm}/bin/dropbox-hm status 2>&1 || true)"

          # `case` and NEVER `grep -q`: under pipefail the producer dies of SIGPIPE and the pipeline
          # returns an ERROR despite the match. The texts come from the official CLI.
          case "$out" in
            *"To link this computer"*) state_now=unlinked ;;
            *"isn't running"*) state_now=dead ;;
            *) state_now=ok ;;
          esac

          state="''${XDG_RUNTIME_DIR:-/tmp}/dropbox-link-watch.state"
          if [ "$state_now" = ok ]; then
            rm -f "$state" # back to normal, so the next break warns immediately
            exit 0
          fi

          # Anti-spam, 12 h per state (the disk-watch idiom): an alarm that tires does not protect.
          now="$(date +%s)"
          if [ -f "$state" ]; then
            read -r last_state last_ts < "$state" || true
            if [ "$last_state" = "$state_now" ] && [ "$((now - last_ts))" -lt 43200 ]; then
              exit 0
            fi
          fi

          # It only NOTIFIES: systemd owns the restarting (rule 15), and relinking needs a BROWSER.
          case "$state_now" in
            unlinked)
              title="Dropbox UNLINKED, nothing is syncing"
              body="The daemon is up, but with no account. Relink with:
      dropbox-hm status   (copy the URL and authorize it in the browser)"
              ;;
            *)
              title="Dropbox is down"
              body="The daemon did not answer. Investigate with:
      systemctl --user status dropbox"
              ;;
          esac

          # `<4>` is systemd's warning prefix, without which LogLevelMax would swallow the line. It logs
          # ALWAYS, because if the session broke there is no notification daemon left to receive it.
          printf '<4>%s, %s\n' "$title" "$state_now" >&2
          notify-send -a "Dropbox" -u critical -i dropbox "$title" "$body" || true

          printf '%s %s\n' "$state_now" "$now" > "$state"
    '';
  };
in
{
  services.dropbox.enable = enabled; # the default folder is ~/Dropbox
  services.dropbox.package = lib.mkIf enabled dropboxCli;

  home.packages = lib.mkIf enabled [ dropboxHm ];

  # BLOCK 1: systemd does NOT notice this daemon dying (it double-forks, so no SIGCHLD), and it
  # says so in the log. ExitType=cgroup fixes the criterion. See the notes.
  systemd.user.services.dropbox = lib.mkIf enabled {
    Unit = {
      # A real crash-loop blows the limit and DIES visibly, instead of restarting forever (the
      # lesson of Spotify's 4145 starts).
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
      # Tied to the session, which is what gives the icon its display. WITH NO SESSION THERE IS NO
      # SYNC, and that trade is stated in full in the notes.
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExitType = "cgroup";
      Restart = lib.mkForce "always"; # mkForce: the module already sets on-failure
      RestartSec = 10;
      # mkForce and not one more item: Environment is a LIST, and beating upstream's empty DISPLAY=
      # would depend on merge ORDER. Only HOME stays; the display comes INHERITED.
      Environment = lib.mkForce [ "HOME=${dropboxHome}" ];
    };
    # mkForce: with default.target too, boot would start it headless and the session would not
    # restart an already-active unit.
    Install.WantedBy = lib.mkForce [ "graphical-session.target" ];
  };

  # BLOCK 2: the daemon alive, active, exit 0 and UNLINKED. No process metric sees that, so the
  # only way is to ASK it (the same active probe Sunshine uses).
  systemd.user.services.dropbox-link-watch = lib.mkIf enabled {
    Unit = {
      Description = "Warns if Dropbox is up but not syncing (unlinked)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      StartLimitIntervalSec = 3600;
      StartLimitBurst = 5;
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${linkWatch}/bin/dropbox-link-watch";
      # The script is silent when fine; this cuts systemd's own "Starting/Finished" per trigger.
      LogLevelMax = "warning";
    };
    # NO Install, on purpose: the TIMER is the only trigger. A `WantedBy=graphical-session.target`
    # here ALSO fired the oneshot at session start, before the daemon's handshake and before any
    # notification daemon existed, and every boot logged a FALSE "down" plus a dead toast.
  };

  systemd.user.timers.dropbox-link-watch = lib.mkIf enabled {
    Unit.Description = "Periodic check of the Dropbox link";
    Timer = {
      # 3min so the daemon can handshake first, otherwise startup becomes a false alarm; 30min is
      # plenty, since an unlink does not resolve itself and the damage grows in days.
      OnActiveSec = "3min";
      # 30min is plenty of resolution: an unlink does not resolve itself, and the damage grows
      # in days (10, in the incident), not in minutes.
      OnUnitActiveSec = "30min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
