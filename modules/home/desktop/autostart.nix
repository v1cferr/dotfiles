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
    coreutils
    discord
    procps
    spotifast
    writeShellScript
    zapfast
    ;

  # ChatGPT is THE one modules/home/apps/chatgpt.nix installs (the Codex override), by store path.
  chatgpt = lib.findFirst (
    p: (p.pname or "") == "chatgpt"
  ) (throw "autostart: chatgpt is not in home.packages") config.home.packages;

  # For an app with NO tray-only flag: leaves a marker named after its PID, and the hook in
  # hypr/lua/autostart.lua sends that PID's first window to special:minimized, unfocused.
  # Exits 1 (systemd: "condition failed", a skip and not a failure) when the app is already up, so a
  # second launch never hands off to the live instance, which would RAISE its window.
  notRunning = writeShellScript "autostart-not-running" ''
    ! ${procps}/bin/pgrep -u "$(${coreutils}/bin/id -u)" -x "$1" >/dev/null
  '';

  hideMarker = writeShellScript "autostart-hide-marker" ''
    ${coreutils}/bin/mkdir -p "$XDG_RUNTIME_DIR/autostart-hide"
    ${coreutils}/bin/touch "$XDG_RUNTIME_DIR/autostart-hide/$MAINPID"
  '';

  # The apps table: adding one is 1 entry here plus 1 line in the panel below. Every app opens in
  # the BACKGROUND: its own tray-only flag when it has one, `hide = true` when it does not.
  apps = {
    chatgpt = {
      # No tray and no start-hidden flag (`--no-startup-window` measured: ignored), so the window
      # is hidden by the compositor. Bring it back with SUPER+CTRL+M or by launching it again.
      exec = "${chatgpt}/bin/chatgpt";
      desc = "ChatGPT and Codex";
      proc = "ChatGPT";
      hide = true;
    };
    discord = {
      # `--start-minimized` = the tray only, like the others. Keep the app's own "Open Discord" on
      # startup Off, which is a second owner (rule 15).
      exec = "${discord}/bin/Discord --start-minimized";
      desc = "chat/voice";
      proc = ".Discord-wrappe"; # the kernel's 15-char comm
    };
    localsend = {
      # `--hidden` = the tray icon only, which is what a RECEIVER needs. Do NOT also turn on the
      # app's own autostart, which is a second owner (rule 15): docs/notes/desktop/autostart.md
      exec = "${osConfig.programs.localsend.package}/bin/localsend_app --hidden";
      desc = "file transfer over the LAN";
    };
    spotifast = {
      # `--start-hidden` = the tray only. Keep its own "start with computer" Off, which is a second
      # owner (rule 15), the same as LocalSend's above.
      exec = "${spotifast}/bin/spotifast --start-hidden";
      desc = "music";
    };
    zapfast = {
      # `--start-hidden` = the tray only. Its own "start with system" writes a .desktop pinned to a
      # store path (it dies on GC), a second owner (rule 15), so it stays Off in the app.
      exec = "${zapfast}/bin/zapfast --start-hidden";
      desc = "WhatsApp";
      proc = ".zapfast-wrappe";
    };
  };

  enabled = lib.filterAttrs (n: _: config.my.autostart.${n}) apps;
in
{
  options.my.autostart = lib.genAttrs (lib.attrNames apps) (n: lib.mkEnableOption n);

  config = {
    # THE PANEL: edit here to turn on/off what opens at login.
    # Dropbox is not here: it is a sync SERVICE, toggled in hosts/<host>/services.nix.
    my.autostart = {
      chatgpt = true; # ChatGPT, its window sent to special:minimized
      discord = true; # chat/voice
      localsend = false; # the LAN file receiver, hidden in the tray
      spotifast = false; # music
      zapfast = true; # WhatsApp, hidden in the tray
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
          # A rebuild never relaunches a running app: a second launch hands off to the live instance,
          # which RAISES its window. The new unit applies at the next login.
          X-SwitchMethod = "keep-old";
        };
        Service = {
          ExecStart = app.exec;
          Restart = "on-failure";
          RestartSec = 5;
          # Chromium apps move THEMSELVES into an app-<name>-<pid>.scope, so the unit empties out at
          # once. Without this it reads inactive, and every rebuild's switch started it again.
          RemainAfterExit = true;
        }
        // lib.optionalAttrs (app ? proc) { ExecCondition = "${notRunning} ${app.proc}"; }
        // lib.optionalAttrs (app.hide or false) { ExecStartPost = "${hideMarker}"; }
        // lib.optionalAttrs (app ? successExit) { SuccessExitStatus = app.successExit; };
        Install.WantedBy = [ "graphical-session.target" ];
      }
    ) enabled;
  };
}
