# The Hyprland CONFIG in Lua (~/.config/hypr/hyprland.lua), declared. The compositor and the
# session come from system/ (programs.hyprland.enable); here it is ONLY the config file (the
# folder rule: home/ configures, it does not install).
#
# The Lua format (Hyprland 0.55+) replaces the old hyprland.conf (hyprlang), which is
# deprecated. `hl` is a global object injected by Hyprland. If hyprland.lua exists, it is
# loaded instead of the .conf. Docs: https://wiki.hypr.land
#
# The keybinds and window rules are at PARITY with the Arch/Kingston setup (the `arch`
# branch), with the tools adapted to the NixOS stack (wofi/dolphin/quickshell).
#
# HOT-RELOAD: hyprland.lua does NOT live in the store, it comes through mkOutOfStoreSymlink
# from home/desktop/hypr/hyprland.lua (a real file in the repo). Editing the .lua plus
# `hyprctl reload` applies it immediately, with no rebuild. The Lua's scripts
# (minimize-others, brightness-osd) enter the PATH through home.packages, so the .lua calls
# them by name.
{
  pkgs,
  config,
  osConfig,
  inputs,
  ...
}:

let
  # The Quickshell package (a flake input). Bound once because the full path goes past 130
  # columns and repeated itself in every consumer in this file.
  qsPkg = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
  # minimize-others: sends the OTHER windows of the current workspace to special:minimized
  # (pressing it again brings them back). Rewritten for the 0.55 Lua dispatch, since the old
  # `hyprctl dispatch movetoworkspacesilent` broke; now it is hl.dsp.window.move with
  # follow=false (silent). jq and hyprctl enter the script's own PATH.
  minimizeOthers = pkgs.writeShellApplication {
    name = "minimize-others";
    runtimeInputs = with pkgs; [
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

      # Moves a specific window (by address), without following focus. $1=addr $2=target.
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

      # Fallback: the state was lost but there are windows in special:minimized, so restore
      # everything.
      mapfile -t mins < <(
        jq -r '.[] | select(.workspace.name=="special:minimized") | .address' <<< "$clients"
      )
      for addr in "''${mins[@]}"; do
        if [ -n "$addr" ]; then move "$addr" "$current_ws"; fi
      done
    '';
  };

  # brightness-osd: "brightness" through hyprsunset's gamma (this desktop has no real
  # backlight, since brightnessctl and ddcutil are absent). It shows Quickshell's NATIVE OSD
  # (a bottom-center bar) through IPC, and it is not a toast. It only has an effect with
  # hyprsunset running.
  # Usage: brightness-osd up|down|reset. It reads the current gamma, computes the new one and
  # CLAMPS it to [floor, ceil] by setting an ABSOLUTE value, because hyprsunset only clamps the
  # ceiling (max-gamma); below that it went to 0 or negative and glitched the screen.
  brightnessOsd = pkgs.writeShellApplication {
    name = "brightness-osd";
    runtimeInputs = [
      pkgs.hyprland
      pkgs.coreutils
      qsPkg
    ];
    text = ''
      step=10
      floor=20  # the floor: never leaves the screen black or glitched
      ceil=150  # the ceiling is hyprsunset.nix's max-gamma

      # the gamma comes as a FLOAT (for instance "90.000015"), so take only the integer part
      # (cut at the dot), otherwise tr would join the digits ("90000015") and the value would
      # explode.
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

      # pushes Quickshell's native OSD (the bottom-center bar) through IPC; the handler is in
      # home/desktop/quickshell/osd/Osd.qml (target "osd", func brightness).
      qs ipc call osd brightness "$new" "$ceil" >/dev/null 2>&1 || true
    '';
  };

  # monitor-toggle: turns the TV (my.monitors.secondary) on and off IN HYPRLAND, by hand. It is
  # necessary because the TV (or the receiver/switch in between) keeps the HDMI link alive even
  # when off, so DRM stays "connected" and Hyprland NEVER emits monitorremoved, which means
  # monitor-watch has no event to react to and the "ghost monitor" remains (the cursor going to
  # a screen that disappeared). On disable, Hyprland gathers workspaces 5 to 8 back onto the LG
  # by itself; re-enabling restores them with the hyprland.lua params.
  monitorToggle = pkgs.writeShellApplication {
    name = "monitor-toggle";
    runtimeInputs = with pkgs; [
      hyprland
      jq
      coreutils
    ];
    text = ''
      name="${osConfig.my.monitors.secondary}" # SSOT: system/desktop/monitors.nix

      # In the Lua parser (0.55) `hyprctl keyword` is blocked ("Use eval"), so runtime monitor
      # config goes through `hyprctl eval` calling the SAME hl.monitor as hyprland.lua. Turning
      # it back on repeats mode/position/scale from there (keeping the TV to the left of the
      # LG); turning it off is just disabled=true.
      on="hl.monitor({ output = \"$name\", mode = \"1920x1080@60\", position = \"-1920x0\", scale = 1, disabled = false })"
      off="hl.monitor({ output = \"$name\", disabled = true })"

      # present in `hyprctl monitors` (only the ACTIVE ones) means it is on, so turn it off.
      if hyprctl -j monitors | jq -e --arg n "$name" 'any(.[]; .name==$n)' >/dev/null 2>&1; then
        hyprctl eval "$off" >/dev/null 2>&1 || true
        hyprctl notify -1 2000 "rgb(f38ba8)" "TV off, workspaces on the LG" >/dev/null 2>&1 || true
      else
        hyprctl eval "$on" >/dev/null 2>&1 || true
        hyprctl notify -1 2000 "rgb(a6e3a1)" "TV back on" >/dev/null 2>&1 || true
      fi
    '';
  };

  # hypr-session-ensure: derives the Wayland environment FROM THE SOCKET (not from the config)
  # and brings hyprland-session.target up. It has to derive it because it runs outside the
  # compositor: HYPRLAND_INSTANCE_SIGNATURE is the directory name in $XDG_RUNTIME_DIR/hypr/ and
  # WAYLAND_DISPLAY is the wayland-N socket. Without those two in the systemd --user
  # environment, the session's services come up unable to talk to the compositor.
  sessionWatch = pkgs.writeShellApplication {
    name = "hypr-session-ensure";
    runtimeInputs = with pkgs; [
      systemd
      coreutils
      findutils
    ];
    text = ''
      # It runs every 30s, so it exits SILENTLY in the normal case, otherwise that is ~2900
      # lines/day in the journal. It only speaks when it actually had to act, which is the
      # event worth investigating.
      if systemctl --user --quiet is-active hyprland-session.target; then
        exit 0
      fi

      rt="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

      # The most RECENT instance (the dir survives a crash, so take the one with the newest
      # mtime).
      sig="$(find "$rt/hypr" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' 2>/dev/null \
             | sort -rn | head -1 | cut -d' ' -f2-)"
      [ -n "$sig" ] || { echo "no Hyprland instance in $rt/hypr, nothing to do"; exit 0; }

      # WAYLAND_DISPLAY: the first wayland-N socket (ignoring the .lock ones).
      wl="$(find "$rt" -mindepth 1 -maxdepth 1 -name 'wayland-[0-9]*' -not -name '*.lock' \
            -printf '%f\n' 2>/dev/null | sort | head -1)"
      [ -n "$wl" ] || { echo "no wayland socket in $rt, nothing to do"; exit 0; }

      systemctl --user set-environment \
        "HYPRLAND_INSTANCE_SIGNATURE=$sig" "WAYLAND_DISPLAY=$wl" XDG_CURRENT_DESKTOP=Hyprland

      # A no-op if autostart.lua's exec-once already brought the target up.
      systemctl --user start hyprland-session.target
      # <4> = warning: it survives LogLevelMax and marks the ONLY time worth having in the
      # journal.
      echo "<4>hyprland-session.target ensured (sig=$sig display=$wl)"
    '';
  };

  # hypr-monitor-watch: listens to Hyprland's events (socket2) and runs `hyprctl reload` when a
  # monitor CONNECTS or DISCONNECTS. The reload reapplies the config, which recalculates the
  # layout (killing the "ghost monitor", the cursor going to a screen that disappeared) and
  # MOVES the lost monitor's workspaces to the remaining one (TV gone means ws 5-8 land on the
  # LG). It runs as a systemd --user service (not an exec-once in the Lua, so it does not
  # duplicate on reload).
  monitorWatch = pkgs.writeShellApplication {
    name = "hypr-monitor-watch";
    runtimeInputs = with pkgs; [
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
  # Hyprland SESSION tools that the Lua below invokes (keybinds/autostart), with app and config
  # in home (rule 4). The launcher is rofi (home/desktop/launcher.nix, the same tool as the
  # clipboard). wl-clipboard and wl-clip-persist are the clipboard's base (the cliphist history
  # and the rofi picker live in clipboard.nix); pamixer and playerctl serve the media keys;
  # pavucontrol is the mixer (SUPER+S).
  home.packages = with pkgs; [
    minimizeOthers # SUPER+M: minimizes the other windows (the Lua calls it by name)
    brightnessOsd # brightness through hyprsunset's gamma (SHIFT+Vol/0; called by name)
    monitorToggle # SUPER+SHIFT+T: turns the TV on and off in Hyprland (the TV-off ghost)
    wl-clipboard # wl-copy/wl-paste (used by wl-clip-persist and by hand)
    wl-clip-persist # keeps the copy alive after the app closes (cliphist is in clipboard.nix)
    pamixer
    playerctl
    pavucontrol
  ];

  # Idleness (dim at 3 min plus lock at 5 min) and the lock screen live in
  # home/desktop/lockscreen.nix: hypridle and hyprlock through their module (a systemd --user
  # service), no longer a hand-written .conf. SUPER+L (a manual lock) is in the keybinds below.
  #
  # MODULAR CONFIG PLUS HOT-RELOAD: the hyprland.lua entrypoint only does a dofile of the
  # modules in ~/.config/hypr/lua/*.lua (one subject per file:
  # monitors/appearance/input/keybinds/rules/autostart/environment). Both come through
  # mkOutOfStoreSymlink from the REAL files in the repo (mutable), so editing any .lua plus
  # `hyprctl reload` applies immediately, with NO rebuild (the same scheme as quickshell). The
  # scripts the binds call (minimize-others/brightness-osd/monitor-toggle) go to the PATH
  # (home.packages above), so the modules invoke them by NAME, which is why the .lua files can
  # be static.
  xdg.configFile."hypr/hyprland.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/GitHub/v1cferr/dotfiles/home/desktop/hypr/hyprland.lua";
  xdg.configFile."hypr/lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/GitHub/v1cferr/dotfiles/home/desktop/hypr/lua";

  # The user's systemd session. LightDM launches Hyprland "raw" (with no systemd integration),
  # so graphical-session.target, which the desktop's --user services (hyprsunset/hypridle) use
  # as WantedBy, was never activated and none of them came up at login. This target activates
  # it through BindsTo (graphical-session.target refuses a manual start, only a dependency
  # works); the autostart above starts it. It mirrors what the
  # wayland.windowManager.hyprland module would do, since here the config is raw.
  systemd.user.targets.hyprland-session = {
    Unit = {
      Description = "Hyprland session (activates graphical-session.target)";
      BindsTo = [ "graphical-session.target" ];
      Wants = [ "graphical-session-pre.target" ];
      After = [ "graphical-session-pre.target" ];
    };
  };

  # ── The remote access SAFETY NET ────────────────────────────────────────────
  # autostart.lua brings hyprland-session.target up through exec-once. That has a hole that
  # cost dearly on 29/07: if the Lua config BLOWS UP, the following modules do not run, and
  # "autostart" comes after "monitors", so the target never comes up and the machine is left
  # WITHOUT Sunshine and WITHOUT Quickshell. Remotely that is unrecoverable: Hyprland is alive,
  # but nothing else that depends on graphical-session.target is.
  #
  # This takes remote access out of the config's hands: it checks the compositor's SOCKET,
  # which exists even with a broken config, and brings the target up on its own. Redundant with
  # the exec-once on purpose, since `systemctl start` on an already active target is a no-op.
  #
  # A TIMER, not a path unit: with `PathExistsGlob` systemd re-triggers while the condition
  # stays true, so the oneshot exits, the socket is still there, it triggers again, and it
  # loops until `unit-start-limit-hit` (tested, it failed exactly like that). A path unit only
  # works when the service CONSUMES the path. The timer is idempotent by construction and costs
  # nothing.
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
      # It runs every 30s: without this SYSTEMD logs "Starting…/Finished…" on its own and
      # drowns the journal (measured: 1708 lines in one day). Making the script exit silently
      # is NOT enough, since those lines are systemd's, not the script's. `warning` cuts the
      # info out and lets through what the script emits with the <4> prefix, which is precisely
      # the time it acted.
      LogLevelMax = "warning";
    };
  };

  # Reapplies the config on a monitor hotplug (kills the ghost plus moves workspaces).
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
