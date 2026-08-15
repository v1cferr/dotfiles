# QUICKSHELL: the shell/bar in QML (bar, OSD, media, notifications), replacing waybar. The
# binary comes from the official FLAKE (inputs.quickshell, so always the latest; bump with
# `nix flake update quickshell`).
#
# HOT-RELOAD (the reason it is like this): the QML config lives in the REPO
# (home/desktop/quickshell/) and is linked through mkOutOfStoreSymlink, a symlink to the
# MUTABLE file and not to the read-only store. That way Quickshell reloads the QML LIVE on
# save (with no rebuild), and the files stay versioned in git (portable: another machine
# clones the repo at the same path and it works). It is a conscious deviation from rule 3 (it
# is not a pure store symlink), and it is the community pattern for QML ricing.
{
  pkgs,
  config,
  inputs,
  ...
}:

let
  # The Quickshell package (a flake input). Bound once because the full path goes past 130
  # columns and repeated itself in every consumer in this file.
  qsPkg = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
  # qs-restart: kills Quickshell and brings it back. It is needed because the hot-reload does
  # NOT reapply a Repeater delegate (the ws-pills, the notifications), so editing their QML is
  # not enough, the process has to restart.
  #
  # WHY A SCRIPT and not `qs kill; sleep 0.3; qs &` directly in the bind: rule 7 (the logic in
  # the build, the bind being 1 command) and rule 15 (an explicit owner). Starting it through
  # `hyprctl dispatch` makes the COMPOSITOR the parent, the same owner as autostart.lua's
  # exec-once, instead of the process being reparented to init. As a bonus the script works
  # from a shell outside the session, because of the `-i 0`.
  #
  # CORRECTION (30/07): the previous version of this comment claimed the old form did NOT
  # restart anything. That was FALSE. The evidence ("Quickshell with 5h of uptime after
  # pressing SUPER+ESCAPE") had a banal cause: I pressed SUPER+SPACE. Tested afterwards, the
  # old form does restart it; the process just ends up with ppid=1 (systemd), which is normal
  # daemonization and survives. Which means this is an architectural IMPROVEMENT, not a bug
  # fix. It is recorded because inferring a mechanism from an observation that has a simpler
  # explanation is exactly the mistake rule 14 tells you to avoid.
  # tray-native-menu: it triggers the NATIVE context menu of an SNI that does NOT expose
  # DBusMenu (icons coming from xembedsniproxy: wine/Battle.net, pamac). Quickshell's
  # `display()` refuses an item with no menu ("No menu present"), so we call the SNI's
  # ContextMenu() method at the cursor position, and the proxy forwards it to X11 and the app
  # draws its own menu there.
  #
  # CORRECTION (30/07): this comment cited xembedsniproxy as if it existed here, and it was NOT
  # installed, so this helper was dead code, justified by a comment describing an absent
  # component. Now the proxy is actually declared (see systemd.user.services.xembedsniproxy at
  # the end of this file) and the path is real.
  #
  # PORTED from the Arch waybar (30/07): Bar.qml called
  # `$HOME/.config/waybar/scripts/tray-native-menu.sh`, a WAYBAR path, and waybar was REMOVED
  # in the migration. The directory does not exist on this machine and the script was not in
  # the repo, so right-clicking those icons failed SILENTLY. Now it lives in the build (rule 7)
  # and the QML calls it by NAME, through the PATH.
  trayNativeMenu = pkgs.writeShellApplication {
    name = "tray-native-menu";
    runtimeInputs = with pkgs; [
      hyprland
      systemd
      coreutils
    ];
    text = ''
      target_id="''${1:-}"
      [ -z "$target_id" ] && exit 2

      # the cursor's global position ("x, y") into two integers
      pos="$(hyprctl cursorpos 2>/dev/null || true)"
      gx="''${pos%%,*}"; gy="''${pos##*,}"
      gx="''${gx//[[:space:]]/}"; gy="''${gy//[[:space:]]/}"
      case "$gx" in ""|*[!0-9]*) gx=0 ;; esac
      case "$gy" in ""|*[!0-9]*) gy=0 ;; esac

      items="$(busctl --user get-property org.kde.StatusNotifierWatcher \
        /StatusNotifierWatcher org.kde.StatusNotifierWatcher \
        RegisteredStatusNotifierItems 2>/dev/null || true)"

      for tok in $items; do
        # the entries come quoted ("svc/path"); the "as" and the count do not
        entry="''${tok//\"/}"
        [ "$entry" = "$tok" ] && continue
        svc="''${entry%%/*}"; path="/''${entry#*/}"
        id="$(busctl --user get-property "$svc" "$path" \
          org.kde.StatusNotifierItem Id 2>/dev/null || true)"
        id="''${id#s \"}"; id="''${id%\"}"
        if [ "$id" = "$target_id" ]; then
          busctl --user call "$svc" "$path" \
            org.kde.StatusNotifierItem ContextMenu ii "$gx" "$gy" 2>/dev/null
          exit 0
        fi
      done
      exit 1
    '';
  };

  qsRestart = pkgs.writeShellApplication {
    name = "qs-restart";
    runtimeInputs = [
      qsPkg
      pkgs.hyprland
      pkgs.coreutils
    ];
    text = ''
      qs kill >/dev/null 2>&1 || true # with no instance running, the kill fails and that is fine
      sleep 0.3
      # `-i 0` finds the instance without HYPRLAND_INSTANCE_SIGNATURE, so it also works over SSH.
      hyprctl -i 0 dispatch 'hl.dsp.exec_cmd("qs")'
    '';
  };
in
{
  home.packages = [
    qsPkg # `qs` / `quickshell`
    pkgs.lm_sensors # `sensors`, the CPU temp read by bar/Bar.qml
    qsRestart # `qs-restart`, used by the SUPER+ESCAPE bind (keybinds.lua)
    trayNativeMenu # `tray-native-menu`, right click on an SNI with no DBusMenu (Bar.qml)
  ];

  # ~/.config/quickshell points at the real file in the repo (mutable), which is the hot-reload.
  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/GitHub/v1cferr/dotfiles/home/desktop/quickshell";

  # ── The XEmbed to StatusNotifierItem bridge ────────────────────────────────
  # A legacy X11 app (Wine/Bottles, and therefore Battle.net) publishes its tray icon through
  # the OLD protocol, XEmbed (_NET_SYSTEM_TRAY_S0), and not through the SNI the bar
  # understands. With no XEmbed host, Wine gives up and draws the tray in a LITTLE WINDOW of
  # its own: MEASURED as `class=explorer.exe`, 160x20, floating over the desktop. That was the
  # annoyance, since the Battle.net icon never reached the bar.
  #
  # xembedsniproxy hosts the XEmbed selection and republishes each icon as an SNI. VERIFIED
  # live with Battle.net open: it went from 3 to 4 items in the StatusNotifierWatcher and the
  # `explorer.exe` little window DISAPPEARED (the icon was embedded into the proxy).
  #
  # THE COST, measured and accepted: the binary only exists inside kdePackages.plasma-workspace,
  # which brings 758 new MiB to this closure, 429 MiB of them qtwebengine, plus kwin, breeze
  # and oxygen-icons. Ugly on a Hyprland system. The alternatives were discarded with a reason:
  # (a) `snixembed` goes the OPPOSITE way (it publishes SNI as XEmbed, for old bars) and
  # therefore tries to be the StatusNotifierWatcher itself, dying with "could not acquire
  # watcher name" because Quickshell already is the watcher; (b) there is no standalone package
  # in nixpkgs (checked: xembed-sni-proxy and xembedsniproxy do not exist as attributes);
  # (c) extracting the binary by hand does not escape the weight, since plasma-workspace
  # references kwin, breeze and oxygen-icons DIRECTLY; (d) `stalonetray` would be another
  # floating window, which is the original problem coming back.
  #
  # A known LIMITATION of the icon that comes through here (measured): it has NO name and NO
  # menu. `Id` is the X11 window ID in decimal ("14680080"), `Title` and `ToolTip` are empty
  # and `Menu` does not exist. That is why right click falls into tray-native-menu (above) and
  # why a future tooltip cannot settle for the `Id`: for these it would have to resolve the X11
  # window's WM_CLASS.
  #
  # ORDERING: the proxy needs the watcher (Quickshell) to register the items, and Quickshell is
  # NOT a systemd unit (it comes up through autostart.lua's exec-once), so there is no way to
  # order against it. The SNI standard tells the item to re-register when the watcher appears;
  # if the icon ever fails to show up at boot, THIS is where to look first.
  systemd.user.services.xembedsniproxy = {
    Unit = {
      Description = "xembedsniproxy: the XEmbed (X11/Wine) tray bridge to StatusNotifierItem";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      # The same brake as autostart.nix: a loop dies and STAYS VISIBLE instead of running
      # silently.
      StartLimitIntervalSec = 300;
      StartLimitBurst = 3;
    };
    Service = {
      ExecStart = "${pkgs.kdePackages.plasma-workspace}/bin/xembedsniproxy";
      # It needs X11 (XWayland). The DISPLAY comes from the systemd --user environment
      # (measured: DISPLAY=:0 present) and is NOT hardcoded here, otherwise it breaks if
      # XWayland changes number. If XWayland is not up yet, it fails and the 3 attempts give it
      # room.
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
