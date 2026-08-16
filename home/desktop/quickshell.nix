# QUICKSHELL: the shell/bar in QML, from the official flake. The QML lives in the REPO and is
# linked mutable, so it hot-reloads on save. The XEmbed bridge's cost: docs/notes/quickshell.md
{
  pkgs,
  config,
  inputs,
  ...
}:

let
  # The Quickshell package (a flake input), bound once because the path repeats in every consumer.
  qsPkg = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
  # qs-restart (SUPER+ESCAPE): the hot-reload does NOT reapply a Repeater delegate, so the
  # process has to restart. Why a script and not the bind: rules 7 and 15, plus the notes.
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
      # `-i 0` finds the instance without the signature, so this also works over SSH.
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

  # THE XEmbed to SNI BRIDGE: Wine/Battle.net publishes the old X11 protocol, and with no host it
  # draws its own floating window. It costs 758 MiB of closure, measured and accepted (notes).
  systemd.user.services.xembedsniproxy = {
    Unit = {
      Description = "xembedsniproxy: the XEmbed (X11/Wine) tray bridge to StatusNotifierItem";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      # The same brake as autostart.nix: a loop dies VISIBLY instead of running silently.
      StartLimitIntervalSec = 300;
      StartLimitBurst = 3;
    };
    Service = {
      ExecStart = "${pkgs.kdePackages.plasma-workspace}/bin/xembedsniproxy";
      # It needs XWayland. DISPLAY comes from the systemd --user env and is NOT hardcoded, otherwise
      # it breaks when XWayland changes number; the 3 attempts cover it not being up yet.
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
