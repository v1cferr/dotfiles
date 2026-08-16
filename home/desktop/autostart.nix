# THE AUTOSTART PANEL: what OPENS along with the graphical session, in a single place.
# Edit true/false in the panel below plus `rebuild`. It mirrors the idiom of
# system/services/toggles.nix (mkEnableOption plus a gate), but for GUI APPS.
#
# AN INDEX: what comes up at boot lives in THREE places, for different reasons:
#   1. HERE (my.autostart)      -> GUI apps with no service of their own: Discord, Spotify,
#      LocalSend (this one has a NixOS module, but only for the package and the firewall; what
#      BRINGS IT UP is this panel).
#   2. my.services.<n>          -> real services, with a module/daemon of their own
#      (dropbox, jellyfin, ollama, sunshine, restic and so on). The keys are declared in
#      system/services/toggles.nix; the true/false belongs to the host
#      (hosts/<host>/services.nix).
#   3. hypr/lua/autostart.lua   -> session infrastructure that NEEDS the compositor's exec-once:
#      hyprlock (the machine comes up locked), quickshell (the bar) and wl-clip-persist. The
#      TRIGGER is still the exec-once (only the compositor knows the right moment), but hyprlock
#      itself is a unit (hyprlock.service, desktop/lockscreen.nix): boot, idle and the bar's
#      button all go through the same owner.
#
# WHY A SERVICE AND NOT exec-once: `exec-once` does NOT restart if the app dies. A systemd
# service does. Restart=on-failure on purpose: a crash comes back, but CLOSING it by hand
# respects the decision. With `always` you would not be able to close the app, since it would
# come back in seconds.
#
# CORRECTION (30/07): this comment used to say "(Electron exits with 0 when you close it)" and it
# WAS FALSE, at least for Spotify, which is not Electron but CEF. What actually happens, MEASURED:
# `bin/spotify` moves the real process into a scope of its own
# (app-org.chromium.Chromium-<pid>.scope, OUTSIDE the unit's cgroup) and the process systemd
# follows EXITS WITH 1, always, even when the app came up perfectly.
# The result with Restart=on-failure: systemd reads "it failed", restarts in 5s, the new launcher
# finds the live instance, prints "Opening in existing browser session", MAKES THE WINDOW SHOW UP
# and exits 1 again. An infinite loop. Measured in one day's journal: 4145 restarts, ~200ms of
# CPU each, and the Spotify window popping up on the screen by itself, which is how the problem
# showed up.
#
# Two defenses, therefore:
#   1. successExit per app (below): for Spotify, exiting 1 IS the normal path, and declaring that
#      makes the unit finish clean instead of "failed" and not restart. The price, stated
#      explicitly: a crash with code 1 does not come back either. Acceptable because, having
#      escaped the cgroup, systemd ALREADY does not supervise the real process. The unit here is a
#      launcher, not a supervisor, and it is honest to say so.
#   2. StartLimit on ALL the units: at most 3 starts in 5min. If this ever goes back into a loop,
#      the unit DIES and stays visible in `systemctl --user --failed`, instead of running 4145
#      times in silence. The root cause of the damage was not just the exit code, it was that
#      there was no limit at all: with RestartSec=5 it made 2 starts/10s, always under the default
#      burst=5, so the factory brake never got to act.
#
# The packages come from home/packages.nix, except LocalSend, whose owner is
# system/net/localsend.nix (the nixpkgs module ties package and firewall together). Here we only
# REFERENCE the binary by store path (it is not installed again, it is the same path, so it does
# not break rule 4).
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  # The apps table: adding one is 1 entry here plus 1 line in the panel below.
  # Discord's binary is `Discord` (capitalized), which is what its own .desktop uses.
  apps = {
    discord = {
      exec = "${pkgs.discord}/bin/Discord";
      desc = "chat/voice";
    };
    localsend = {
      # `--hidden` comes up WITHOUT a window, only the tray icon (SNI), which is what makes sense
      # for a receiver: LocalSend only RECEIVES a file if it is open, and sending from the phone
      # cannot require walking to the PC to open the app.
      # WARNING: the bar's tray (quickshell) becomes the ONLY way to bring the window back. If
      # the bar is not up, it keeps running invisible.
      # WARNING: do NOT turn on "Autostart after login" in THE APP's settings. That writes a
      # .desktop into ~/.config/autostart and would become a SECOND owner of the same automation
      # (rule 15), with two instances fighting over 53317.
      # The binary is `localsend_app` (which is what its .desktop uses), and the package comes
      # from the module's option instead of `pkgs.localsend`: if it ever becomes
      # `unstable.localsend` in system/, the autostart follows on its own. It is the spotify trap
      # (below) solved by construction, not by attention.
      exec = "${osConfig.programs.localsend.package}/bin/localsend_app --hidden";
      desc = "file transfer over the LAN";
    };
    spotify = {
      # unstable.* has to MATCH home/packages.nix, otherwise the autostart brings up the broken
      # version from the base while the menu opens the good one (see the justification there).
      #
      # The `--no-zygote` flag that keeps the app standing does NOT come from here: it belongs to
      # the PACKAGE, baked in by flake.nix's overlaySpotifyNoZygote. That way the menu
      # (`Exec=spotify` through the PATH) gets the same flag as this autostart, a single owner
      # (rule 15), instead of the flag existing here and being missing there.
      exec = "${pkgs.unstable.spotify}/bin/spotify";
      desc = "music";
      # Exiting with 1 is the NORMAL path here (it escapes into a scope of its own; see the
      # header). Without this, on-failure restarts every 5s and the window reappears by itself.
      successExit = "1";
    };
  };

  enabled = lib.filterAttrs (n: _: config.my.autostart.${n}) apps;
in
{
  options.my.autostart = lib.genAttrs (lib.attrNames apps) (n: lib.mkEnableOption n);

  config = {
    # ── THE PANEL: edit here to turn on/off what opens at login ───────────────
    my.autostart = {
      discord = true; # chat/voice
      localsend = true; # the LAN file receiver, hidden in the tray
      spotify = true; # music
    };

    # One --user service per enabled app, tied to graphical-session.target: it comes up when the
    # session comes up and goes down with it (it does not survive a logout as an orphan process).
    systemd.user.services = lib.mapAttrs' (
      name: app:
      lib.nameValuePair "autostart-${name}" {
        Unit = {
          Description = "Autostart: ${name} (${app.desc})";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
          # The loop brake (see the header): 3 starts in 5min and the unit gives up, FAILING
          # visibly. The default (5 in 10s) never acted with RestartSec=5.
          StartLimitIntervalSec = 300;
          StartLimitBurst = 3;
        };
        Service = {
          ExecStart = app.exec;
          Restart = "on-failure";
          RestartSec = 5;
        }
        // lib.optionalAttrs (app ? successExit) { SuccessExitStatus = app.successExit; };
        Install.WantedBy = [ "graphical-session.target" ];
      }
    ) enabled;
  };
}
