# ═══════════════════════════════════════════════════════════════════════════
# DROPBOX: the ~/Dropbox folder synced (the Obsidian vault plus documents).
#
# A conscious exception to the "home/ does not install" rule: services.dropbox is a USER
# SERVICE (systemd --user), not a package in environment.systemPackages. The home-manager
# module already brings dropbox-cli and starts the daemon, so here it is only ENABLED.
#
# Why the official client and not Maestral: home-manager has an official maintained module for
# this one; Maestral was archived upstream, has no module and has a known bug on NixOS (it
# loses its config on logout, nixpkgs#307898).
#
# The intended use is only Obsidian .md notes and documents (the free plan, 2 GB), with no
# binaries and no large files. The restic repo (the heavy backup) does NOT come here.
#
# First use or RE-linking: the daemon prints a URL to authorize in the browser
#   dropbox-hm status   # copy the link and authorize; do NOT use `dropbox status` (see below)
# The client downloads its own binary into ~/.dropbox-dist (state, outside Nix), which is the
# imperative part Dropbox imposes; the rest (enabling and starting) is declared.
#
# ── THE TRAY: THE ICON REQUIRES A SESSION, AND THAT COSTS THE 24/7 ─────────
# The home-manager module pins an EMPTY `DISPLAY=` on the unit, on purpose: to it, this is a
# headless daemon. The price is having no tray icon, MEASURED on 11/08/2026 on the live
# process: zero Wayland or X11 fds open, and the SNI watcher listing LocalSend, Sunshine and
# Discord WITHOUT Dropbox. It was never the bar's fault.
#
# Here that default is INVERTED, because the icon is wanted. It is enough for the daemon to
# inherit the session's display for it to register `dropbox_client_<pid>` in the watcher
# immediately (measured). And the bar already knows how to draw it: the
# `image://icon/<name>?path=<dir>` that Dropbox publishes has its own handling in
# desktop/quickshell/bar/Bar.qml.
#
# `DISPLAY=:0`/`WAYLAND_DISPLAY=wayland-1` are NOT hardcoded here: the socket name belongs to
# the session, not to the host, and tomorrow it is `wayland-2`. autostart.lua already does
# `systemctl --user import-environment WAYLAND_DISPLAY …`, so the user manager HAS both
# variables, and the remedy is only to STOP zeroing DISPLAY and let the unit inherit it (hence
# the `Environment` going in with mkForce, without the `DISPLAY=`).
#
# THE COST, stated explicitly: inheriting the display requires being STARTED by the graphical
# session. `After=` alone would not solve it, because what brings graphical-session.target up
# is the compositor's exec-once, OUTSIDE the default.target transaction, so at boot the service
# started earlier and fell back into headless (which is what was seen: dropbox and quickshell
# both at 07:11:42). So Install becomes graphical-session.target, and the consequence is
# honest: WITH NO SESSION THERE IS NO SYNC. On this machine that is cheap (autologin, always
# on, see system/core/users.nix), but it is a real trade, and it inherits the trap already
# noted in desktop/polkit-agent.nix (home-manager#8547): if graphical-session.target ever goes
# inactive, the sync stops with it. That is why the watcher in block 2 also LOGS at warning
# level and does not only notify: with no session there is no toast to see, but the journal is
# still there.
#
# ── THE INCIDENT THIS FILE EXISTS NOT TO REPEAT ────────────────────────────
# Discovered on 11/08/2026: the daemon had been `active (running)` for 6 h, with not one error
# line, and UNLINKED since ~01/08 (`unlink.db` rewritten; the hostkeys and sync_history.db
# frozen on 31/07). Which means 10 days syncing NOTHING, with the service declaring itself
# healthy. Two independent causes, and each has its remedy below:
#   1. systemd did NOT notice the daemon dying  -> ExitType/Restart (block 1)
#   2. NOTHING noticed the "alive but unlinked" -> the healthcheck (block 2)
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  enabled = osConfig.my.services.dropbox;

  # The daemon runs with its OWN HOME (~/.dropbox-hm), a decision of the home-manager module
  # and not of this repo. And the CLI only finds the daemon's socket if it inherits the SAME
  # HOME: in a normal shell, `dropbox status` answers "Dropbox isn't running!" with the daemon
  # alive right next to it. That LIE is what makes diagnosing by hand go wrong (it is how the
  # incident above went unnoticed), hence the wrapper.
  dropboxHome = "${config.home.homeDirectory}/.dropbox-hm";
  dropboxCmd = lib.getExe' config.services.dropbox.package "dropbox";

  # The CLI with the right HOME: `dropbox-hm status`, `dropbox-hm start`, `… exclude`. It does
  # not reinstall dropbox-cli, it references the module's SAME store path, the way autostart
  # does with LocalSend (so it does not break rule 4).
  dropboxHm = pkgs.writeShellApplication {
    name = "dropbox-hm";
    text = ''
      export HOME=${lib.escapeShellArg dropboxHome}
      exec ${dropboxCmd} "$@"
    '';
  };

  linkWatch = pkgs.writeShellApplication {
    name = "dropbox-link-watch";
    runtimeInputs = with pkgs; [
      coreutils
      libnotify
    ];
    text = ''
          # `timeout` because the CLI BLOCKS waiting for the daemon's socket: a hung daemon
          # would hang the timer with it, and a stuck timer warns about nothing, which is
          # exactly the failure mode this script exists to cover.
          out="$(timeout 30 ${dropboxHm}/bin/dropbox-hm status 2>&1 || true)"

          # `case` and NEVER `grep -q`: with writeShellApplication's pipefail the grep exits on
          # the 1st match, the producer dies of SIGPIPE and the pipeline returns an ERROR
          # despite the match (the same trap already noted in home/net/mega.nix).
          # The texts come from the official CLI: "To link this computer to a Dropbox account,
          # visit the following url" and "Dropbox isn't running!".
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

          # Anti-spam, the same idiom as disk-watch: 12 h per state. Without it an unlink would
          # become a notification every 30 min and the person would learn to ignore it, and an
          # alarm that tires is an alarm that does not protect.
          now="$(date +%s)"
          if [ -f "$state" ]; then
            read -r last_state last_ts < "$state" || true
            if [ "$last_state" = "$state_now" ] && [ "$((now - last_ts))" -lt 43200 ]; then
              exit 0
            fi
          fi

          # It only NOTIFIES, it never restarts: what keeps the daemon up is systemd (block 1).
          # Two owners for the same automation is rule 15, and in the unlink case restarting
          # would solve nothing, because relinking requires authorizing in the BROWSER: it is
          # imperative by Dropbox's imposition, not out of laziness.
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

          # `<4>` is systemd's level prefix (warning); without it the line would come out at
          # `info` and the unit's LogLevelMax=warning would SWALLOW it. It logs ALWAYS and not
          # only when the toast fails: the sync now depends on the graphical session (see the
          # header), and if that session is exactly what broke there is no notification daemon
          # to receive the warning. The journal is the fallback.
          printf '<4>%s, %s\n' "$title" "$state_now" >&2
          notify-send -a "Dropbox" -u critical -i dropbox "$title" "$body" || true

          printf '%s %s\n' "$state_now" "$now" > "$state"
    '';
  };
in
{
  services.dropbox.enable = enabled; # the default folder is ~/Dropbox

  home.packages = lib.mkIf enabled [ dropboxHm ];

  # ── BLOCK 1: making systemd NOTICE the daemon dying ───────────────────────
  # The home-manager module delivers Type=forking plus PIDFile plus Restart=on-failure, and
  # systemd logs on every start:
  #   "Supervising process 1806 which is not our child. We'll most likely not notice when it
  #    exits."
  # That is not noise: it is systemd SAYING that its Restart=on-failure is decorative. The
  # CLI's `dropbox start` does a double fork and the PIDFile's process is not systemd's child,
  # so the death does not arrive as a SIGCHLD, and the service would stay `active` with the
  # daemon already dead, and nothing would restart it.
  #
  # ExitType=cgroup changes the criterion: the unit is alive while THERE IS a process in its
  # cgroup, and the cgroup is something systemd really controls (the daemon does not escape it,
  # checked in `systemctl status`, PIDs 1797/1806 both inside).
  # It requires systemd >= 250; this machine is on 260.
  #
  # `always` and not `on-failure`, and here the choice is the OPPOSITE of
  # home/desktop/autostart.nix, on purpose: there, closing the app by hand is a decision to
  # respect; here a stopped sync daemon is always a defect, including when what stopped it was
  # `dropbox-hm stop`. `systemctl --user stop dropbox` still stops it for real (an explicit
  # stop never triggers Restart).
  systemd.user.services.dropbox = lib.mkIf enabled {
    Unit = {
      # With `always` plus RestartSec=10, a real crash-loop blows the limit and the unit DIES
      # visibly in `systemctl --user --failed`, instead of restarting silently forever, which
      # is the lesson of Spotify's 4145 starts (see autostart).
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
      # Tied to the session because the session is what gives the icon its display (see the
      # header). The same trio as the autostart-* units and polkit-agent: PartOf to go down
      # with it, After to order it, and the WantedBy below to COME UP with it.
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExitType = "cgroup";
      Restart = lib.mkForce "always"; # mkForce: the module already sets on-failure
      RestartSec = 10;
      # mkForce and not one more item: `Environment` is a LIST, and a 2nd `DISPLAY=…` entry
      # would depend on the module's merge ORDER to beat upstream's empty `DISPLAY=`, and
      # nobody guarantees that order. Rewriting the whole list is deterministic. Only HOME
      # stays; DISPLAY and WAYLAND_DISPLAY come INHERITED from the user manager (the
      # import-environment in desktop/hypr/lua/autostart.lua), which is what avoids hardcoding
      # `wayland-1`.
      Environment = lib.mkForce [ "HOME=${dropboxHome}" ];
    };
    # mkForce: the module declares `default.target`, and KEEPING both would be worse than not
    # touching it. At boot, default.target would bring the daemon up BEFORE the session, in
    # headless and with no icon, and graphical-session.target afterwards would not restart it
    # (an already active unit does not start again). Here only the session starts it.
    Install.WantedBy = lib.mkForce [ "graphical-session.target" ];
  };

  # ── BLOCK 2: noticing the "alive but not syncing" ─────────────────────────
  # Block 1 covers a DEAD daemon. The failure mode that cost 10 days is another one: the daemon
  # alive, `active`, exit 0, a clean log, and unlinked. No process metric sees that, so the only
  # way is to ASK it, just like Sunshine's active probe (system/services/sunshine.nix).
  #
  # It is tied to graphical-session.target because the remedy is a notification: with no session
  # there is no notification daemon to receive it, and the alarm would be lost. The Dropbox
  # daemon is NOT tied to the session (it stays 24/7 with linger); only the warning needs
  # somebody in front of the screen to make sense.
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
      # The script exits silently when everything is fine; this cuts the "Starting…/Finished…"
      # that SYSTEMD logs on its own on every trigger (the same lesson as bb8690c, where two
      # timers added up to 2148 lines/day in the journal).
      LogLevelMax = "warning";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.timers.dropbox-link-watch = lib.mkIf enabled {
    Unit.Description = "Periodic check of the Dropbox link";
    Timer = {
      # 3min: the daemon needs to come up and handshake with the cloud before the 1st probe,
      # otherwise the transient startup state would become a false alarm.
      OnActiveSec = "3min";
      # 30min is plenty of resolution: an unlink does not resolve itself, and the damage grows
      # in days (10, in the incident), not in minutes.
      OnUnitActiveSec = "30min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
