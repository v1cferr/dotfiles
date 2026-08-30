# THE AUTOSTART PANEL: the GUI apps that open with the session, as one --user unit each.
# The 3 places boot-time things live, and Spotify's 4145 restarts: docs/notes/desktop/autostart.md
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    discord
    unstable # the CHANNEL and not a package, so `unstable.x` stays greppable at each use site
    ;

  # The apps table: adding one is 1 entry here plus 1 line in the panel below.
  apps = {
    discord = {
      exec = "${discord}/bin/Discord";
      desc = "chat/voice";
    };
    localsend = {
      # `--hidden` = the tray icon only, which is what a RECEIVER needs. Do NOT also turn on the
      # app's own autostart, which is a second owner (rule 15): docs/notes/desktop/autostart.md
      exec = "${osConfig.programs.localsend.package}/bin/localsend_app --hidden";
      desc = "file transfer over the LAN";
    };
    spotify = {
      # unstable.* must MATCH home/packages.nix, or the autostart opens a different build from the
      # menu. The --no-zygote flag belongs to the PACKAGE (flake.nix), so both share one owner.
      exec = "${unstable.spotify}/bin/spotify";
      desc = "music";
      # Exiting 1 is the NORMAL path here (it escapes into its own scope). Without this, on-failure
      # restarts every 5s and the window reappears by itself.
      successExit = "1";
    };
  };

  enabled = lib.filterAttrs (n: _: config.my.autostart.${n}) apps;
in
{
  options.my.autostart = lib.genAttrs (lib.attrNames apps) (n: lib.mkEnableOption n);

  config = {
    # THE PANEL: edit here to turn on/off what opens at login.
    my.autostart = {
      discord = true; # chat/voice
      localsend = true; # the LAN file receiver, hidden in the tray
      spotify = true; # music
    };

    # One --user service per enabled app, tied to the session, so nothing survives a logout.
    systemd.user.services = lib.mapAttrs' (
      name: app:
      lib.nameValuePair "autostart-${name}" {
        Unit = {
          Description = "Autostart: ${name} (${app.desc})";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
          # The loop brake: 3 starts in 5min and the unit gives up, FAILING visibly. The default (5 in
          # 10s) never acted with RestartSec=5, which is how 4145 restarts went unnoticed.
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
