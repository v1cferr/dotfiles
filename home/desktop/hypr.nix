# HYPRLAND's config in Lua (0.55+ replaces hyprlang), hot-reloaded through mkOutOfStoreSymlink.
# The 4 helper scripts and the remote-access safety net: docs/notes/desktop/hypr.md
{
  pkgs,
  config,
  osConfig,
  inputs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    coreutils
    findutils
    hyprland
    jq
    pamixer
    pavucontrol
    playerctl
    socat
    systemd
    wl-clip-persist
    wl-clipboard
    writeShellApplication
    ;

  # The Quickshell package (a flake input), bound once because the path repeats in every consumer.
  qsPkg = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
  # minimize-others (SUPER+M): the others go to special:minimized, and again brings them back.
  # Rewritten for the 0.55 Lua dispatch, since `movetoworkspacesilent` broke.
  minimizeOthers = writeShellApplication {
    name = "minimize-others";
    runtimeInputs = [
      hyprland
      jq
      coreutils
    ];
    text = ''
      active_json="$(hyprctl -j activewindow)"
      active_addr="$(jq -r '.address // empty' <<< "$active_json")"
      current_ws="$(jq -r '.workspace.id // empty' <<< "$active_json")"
      state="/tmp/hypr-minimized-ws-''${current_ws}.list"
      clients="$(hyprctl -j clients)"

      # No focused window or an invalid workspace means there is nothing to do.
      if [ -z "$active_addr" ] || [ -z "$current_ws" ] || [ "$current_ws" = "-1" ]; then
        exit 0
      fi

      # Moves a specific window by address, without following focus. $1=addr $2=target.
      move() {
        hyprctl dispatch "hl.dsp.window.move({workspace=\"$2\", window=\"address:$1\", follow=false})" >/dev/null || true
      }

      # Restore toggle: if we already minimized in this workspace, bring everything back.
      if [ -s "$state" ]; then
        while IFS= read -r addr; do
          if [ -n "$addr" ]; then move "$addr" "$current_ws"; fi
        done < "$state"
        rm -f "$state"
        exit 0
      fi

      # The addresses of the other windows in this workspace (not the active one).
      mapfile -t others < <(
        jq -r --arg a "$active_addr" --argjson w "$current_ws" \
          '.[] | select(.workspace.id==$w) | select(.address!=$a) | .address' <<< "$clients"
      )

      if [ "''${#others[@]}" -gt 0 ]; then
        printf '%s\n' "''${others[@]}" > "$state"
        for addr in "''${others[@]}"; do
          if [ -n "$addr" ]; then move "$addr" "special:minimized"; fi
        done
        [ -s "$state" ] || rm -f "$state"
        exit 0
      fi

      # Fallback: the state was lost but there ARE minimized windows, so restore everything.
      mapfile -t mins < <(
        jq -r '.[] | select(.workspace.name=="special:minimized") | .address' <<< "$clients"
      )
      for addr in "''${mins[@]}"; do
        if [ -n "$addr" ]; then move "$addr" "$current_ws"; fi
      done
    '';
  };

  # brightness-osd: "brightness" through hyprsunset's gamma, since this desktop has no backlight.
  # It CLAMPS to an absolute [floor, ceil], because hyprsunset only clamps the ceiling.
  brightnessOsd = writeShellApplication {
    name = "brightness-osd";
    runtimeInputs = [
      hyprland
      coreutils
      qsPkg
    ];
    text = ''
      step=10
      floor=20  # the floor: never leaves the screen black or glitched
      ceil=150  # the ceiling is hyprsunset.nix's max-gamma

      # the gamma comes as a FLOAT, so cut at the dot: `tr` alone would join the digits and explode.
      cur="$(hyprctl hyprsunset gamma 2>/dev/null | cut -d. -f1 | tr -dc '0-9' || true)"
      [ -n "$cur" ] || cur=100

      case "''${1:-up}" in
        up)    new=$((cur + step)) ;;
        down)  new=$((cur - step)) ;;
        reset) new=100 ;;           # back to normal brightness
        *)     new=$cur ;;
      esac

      if [ "$new" -lt "$floor" ]; then new=$floor; fi
      if [ "$new" -gt "$ceil" ];  then new=$ceil;  fi
      hyprctl hyprsunset gamma "$new" >/dev/null 2>&1 || true

      # pushes Quickshell's native OSD through IPC (the handler is in quickshell/osd/Osd.qml).
      qs ipc call osd brightness "$new" "$ceil" >/dev/null 2>&1 || true
    '';
  };

  # monitor-toggle (SUPER+SHIFT+T): the TV keeps the HDMI link alive when off, so Hyprland never
  # emits monitorremoved and the ghost monitor stays. This is the manual way out.
  monitorToggle = writeShellApplication {
    name = "monitor-toggle";
    runtimeInputs = [
      hyprland
      jq
      coreutils
    ];
    text = ''
      name="${osConfig.my.monitors.secondary}" # SSOT: system/desktop/monitors.nix

      # In the 0.55 parser `hyprctl keyword` is blocked ("Use eval"), so this calls the SAME
      # hl.monitor as hyprland.lua does, repeating mode/position/scale from there.
      on="hl.monitor({ output = \"$name\", mode = \"1920x1080@60\", position = \"-1920x0\", scale = 1, disabled = false })"
      off="hl.monitor({ output = \"$name\", disabled = true })"

      # present in `hyprctl monitors` (the ACTIVE ones) means it is on, so turn it off.
      if hyprctl -j monitors | jq -e --arg n "$name" 'any(.[]; .name==$n)' >/dev/null 2>&1; then
        hyprctl eval "$off" >/dev/null 2>&1 || true
        hyprctl notify -1 2000 "rgb(${config.my.theme.palette.red})" "TV off, workspaces on the LG" >/dev/null 2>&1 || true
      else
        hyprctl eval "$on" >/dev/null 2>&1 || true
        hyprctl notify -1 2000 "rgb(${config.my.theme.palette.green})" "TV back on" >/dev/null 2>&1 || true
      fi
    '';
  };

  # hypr-session-ensure: it DERIVES the Wayland env from the SOCKET, because it runs outside the
  # compositor and the session's services cannot talk to it without those two variables.
  sessionWatch = writeShellApplication {
    name = "hypr-session-ensure";
    runtimeInputs = [
      systemd
      coreutils
      findutils
    ];
    text = ''
      # It runs every 30s, so it is silent in the normal case (~2900 lines/day otherwise).
      if systemctl --user --quiet is-active hyprland-session.target; then
        exit 0
      fi

      rt="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

      # The most RECENT instance: the dir survives a crash, so take the newest mtime.
      sig="$(find "$rt/hypr" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' 2>/dev/null \
             | sort -rn | head -1 | cut -d' ' -f2-)"
      [ -n "$sig" ] || { echo "no Hyprland instance in $rt/hypr, nothing to do"; exit 0; }

      # WAYLAND_DISPLAY: the first wayland-N socket, ignoring the .lock ones.
      wl="$(find "$rt" -mindepth 1 -maxdepth 1 -name 'wayland-[0-9]*' -not -name '*.lock' \
            -printf '%f\n' 2>/dev/null | sort | head -1)"
      [ -n "$wl" ] || { echo "no wayland socket in $rt, nothing to do"; exit 0; }

      systemctl --user set-environment \
        "HYPRLAND_INSTANCE_SIGNATURE=$sig" "WAYLAND_DISPLAY=$wl" XDG_CURRENT_DESKTOP=Hyprland

      # A no-op if autostart.lua's exec-once already brought the target up.
      systemctl --user start hyprland-session.target
      # <4> = warning: it survives LogLevelMax and marks the ONLY moment worth logging.
      echo "<4>hyprland-session.target ensured (sig=$sig display=$wl)"
    '';
  };

  # hypr-monitor-watch: on monitoradded/removed it reloads, which kills the ghost and moves the
  # orphaned workspaces. A user SERVICE and not an exec-once, so a reload does not duplicate it.
  monitorWatch = writeShellApplication {
    name = "hypr-monitor-watch";
    runtimeInputs = [
      hyprland
      socat
      coreutils
    ];
    text = ''
      sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
      socat -u "UNIX-CONNECT:$sock" - | while IFS= read -r line; do
        case "$line" in
          monitoradded*|monitorremoved*)
            sleep 0.4  # lets Hyprland settle the hotplug before the reload
            hyprctl reload >/dev/null 2>&1 || true
            ;;
        esac
      done
    '';
  };
in
{
  # The Hyprland SESSION tools the Lua invokes BY NAME, which is what keeps the .lua static.
  home.packages = [
    minimizeOthers # SUPER+M: minimizes the other windows (the Lua calls it by name)
    brightnessOsd # brightness through hyprsunset's gamma (SHIFT+Vol/0; called by name)
    monitorToggle # SUPER+SHIFT+T: turns the TV on and off in Hyprland (the TV-off ghost)
    wl-clipboard # wl-copy/wl-paste (used by wl-clip-persist and by hand)
    wl-clip-persist # keeps the copy alive after the app closes (cliphist is in clipboard.nix)
    pamixer
    playerctl
    pavucontrol
  ];

  # HOT-RELOAD: both come through mkOutOfStoreSymlink from the REAL files, so editing a .lua plus
  # `hyprctl reload` applies with NO rebuild. Idle and the lock are in ./lockscreen.nix.
  xdg.configFile."hypr/hyprland.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/GitHub/v1cferr/dotfiles/home/desktop/hypr/hyprland.lua";
  xdg.configFile."hypr/lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/GitHub/v1cferr/dotfiles/home/desktop/hypr/lua";

  # LightDM launches Hyprland RAW, so graphical-session.target was never activated and none of
  # the --user desktop services came up. This target activates it through BindsTo.
  systemd.user.targets.hyprland-session = {
    Unit = {
      Description = "Hyprland session (activates graphical-session.target)";
      BindsTo = [ "graphical-session.target" ];
      Wants = [ "graphical-session-pre.target" ];
      After = [ "graphical-session-pre.target" ];
    };
  };

  # THE REMOTE ACCESS SAFETY NET: a Lua config that blows up would leave the machine with no
  # Sunshine and no Quickshell, unrecoverable from outside. A TIMER, not a path unit: the notes.
  systemd.user.timers.hyprland-session-watch = {
    Unit.Description = "Periodically ensures Hyprland's graphical-session.target";
    Timer = {
      OnActiveSec = "20s"; # the 1st check right after login
      OnUnitActiveSec = "30s";
    };
    Install.WantedBy = [ "default.target" ]; # active from login on, before the compositor
  };

  systemd.user.services.hyprland-session-watch = {
    Unit.Description = "Brings hyprland-session.target up (the exec-once safety net)";
    Service = {
      Type = "oneshot";
      ExecStart = "${sessionWatch}/bin/hypr-session-ensure";
      # Without this SYSTEMD's own "Starting/Finished" drowns the journal (1708 lines in a day);
      # `warning` still lets the script's <4> through, which is the moment it acted.
      LogLevelMax = "warning";
    };
  };

  # Reapplies the config on a monitor hotplug (it kills the ghost and moves workspaces).
  systemd.user.services.hypr-monitor-watch = {
    Unit = {
      Description = "Reapplies the Hyprland config when a monitor connects or disconnects";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${monitorWatch}/bin/hypr-monitor-watch";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
