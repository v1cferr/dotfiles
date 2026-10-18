# FLAMESHOT v14 plus the keyboard-flow scripts, called by the submap in keybinds.lua.
# The portal-only capture and what broke on the way: docs/notes/apps/flameshot.md
{
  config,
  lib,
  osConfig,
  pkgs,
  inputs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    coreutils
    jq
    libnotify
    unstable # the CHANNEL and not a package, so `unstable.x` stays greppable at each use site
    writeShellApplication
    ;
  # hyprctl from the RUNNING compositor (unstable), never the stable 0.55 a bare pkgs.hyprland is.
  hyprland = osConfig.programs.hyprland.package;

  # The Quickshell package (a flake input), bound once because the path repeats below.
  qsPkg = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
  fs = unstable.flameshot; # v14

  p = config.my.theme.palette; # SSOT: modules/home/desktop/palette.nix (rule 11, decision 0001)
  # The pen's swatches, in hue order: the palette's accents, then its text for a neutral mark.
  penColors = [
    "red"
    "orange"
    "yellow"
    "green"
    "cyan"
    "blue"
    "magenta"
    "text"
  ];

  # flameshot-screenshot: the v14 picker only takes a CLICK, so this opens it and enters a submap,
  # but ONLY with 2+ monitors, which is when a picker exists at all. The watcher resets the submap.
  flameshotScreenshot = writeShellApplication {
    name = "flameshot-screenshot";
    # `qs` hides the bar while the overlay exists. runtimeInputs is mandatory: writeShellApplication
    # uses a restricted PATH, not the user's.
    runtimeInputs = [
      fs
      hyprland
      jq
      coreutils
      qsPkg
    ];
    text = ''
      # With ONE monitor v14 skips the picker and opens the selection straight away, where 1/2/Esc
      # are flameshot's own keys: entering the submap there hijacks them into a bogus click.
      picker=false
      if [ "$(hyprctl monitors -j | jq 'length')" -gt 1 ]; then picker=true; fi

      flameshot gui >/dev/null 2>&1 &
      if $picker; then hyprctl dispatch 'hl.dsp.submap("screenshot")' >/dev/null 2>&1 || true; fi

      fs_open() { hyprctl clients -j | jq -e 'any(.[]; .title=="flameshot")' >/dev/null 2>&1; }
      (
        c=0; while [ "$c" -lt 15 ];  do sleep 0.2; fs_open && break;  c=$((c+1)); done  # wait for it to open (<=3s)
        # THE DUPLICATED BAR: the frozen frame already has the bar in it, so hiding the LIVE one now
        # kills the duplicate without removing it from the shot. See the notes for why hiding.
        fs_open && qs ipc call bar hide >/dev/null 2>&1 || true
        c=0; while [ "$c" -lt 300 ]; do fs_open || break; sleep 0.2;  c=$((c+1)); done  # wait for it to close (<=60s)
        qs ipc call bar unhide >/dev/null 2>&1 || true  # it ALWAYS comes back, the 60s timeout included
        if $picker; then hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null 2>&1 || true; fi
      ) >/dev/null 2>&1 &
    '';
  };

  # flameshot-pick: it clicks the target's preview, resolving the slice DYNAMICALLY from the
  # monitors' physical order, so it survives a turned-off monitor or a rearrangement.
  flameshotPick = writeShellApplication {
    name = "flameshot-pick";
    runtimeInputs = [
      hyprland
      jq
      coreutils
    ];
    text = ''
      target="''${1:?usage: flameshot-pick <monitor>}"
      reset() { hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null 2>&1 || true; }

      # the picker's geometry; with no picker, just reset and exit.
      geo="$(hyprctl clients -j | jq -r '[.[] | select(.title=="flameshot")] | first
        | if . == null then empty else "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])" end')"
      if [ -z "$geo" ]; then reset; exit 0; fi
      read -r px py pw ph <<<"$geo"

      # the target's 0-based index in the left-to-right order of the ACTIVE monitors, plus the total.
      info="$(hyprctl monitors -j | jq -r --arg t "$target" '
        ([ .[] | { name, x } ] | sort_by(.x)) as $m
        | ($m | map(.name) | index($t)) as $i
        | if $i == null then empty else "\($i) \($m | length)" end')"
      if [ -z "$info" ]; then reset; exit 0; fi  # the target is not active (a turned-off monitor, say)
      read -r i n <<<"$info"

      # the preview's center: slice i horizontally, 55% of the height.
      cx=$(( px + pw * (2 * i + 1) / (2 * n) ))
      cy=$(( py + ph * 55 / 100 ))
      hyprctl dispatch "hl.dsp.cursor.move({ x = $cx, y = $cy })" >/dev/null 2>&1 || true
      hyprctl dispatch 'hl.dsp.send_shortcut({ mods = 0, key = "mouse:272", window = "title:flameshot" })' >/dev/null 2>&1 || true
      reset
    '';
  };

  # flameshot-screen: sc1/sc2 by monitor NAME. Qt numbers the screens in wl_output order, which is
  # Hyprland's monitor id order, so `--number` is DERIVED and not measured by hand (rule 11).
  flameshotScreen = writeShellApplication {
    name = "flameshot-screen";
    runtimeInputs = [
      fs
      hyprland
      jq
    ];
    text = ''
      target="''${1:?usage: flameshot-screen <monitor>}"

      # the target's 0-based position among the ACTIVE monitors sorted by id, which is what
      # `--number` counts. Absent means there is nothing to capture (a disconnected TV, say).
      idx="$(hyprctl monitors -j | jq -r --arg t "$target" '
        ([ .[] | { name, id } ] | sort_by(.id) | map(.name) | index($t)) // empty')"
      if [ -z "$idx" ]; then
        hyprctl notify -1 2000 "rgb(${p.red})" "$target is not connected" >/dev/null 2>&1 || true
        exit 0
      fi

      flameshot screen --number "$idx" -c
    '';
  };

  # shell-screenshot: the NixOS Center's capture. It waits for the Center to leave the frame, then
  # shoots one monitor or the whole layout, to the clipboard or to a dated PNG: docs/notes/desktop/nixos-center.md
  shellScreenshot = writeShellApplication {
    name = "shell-screenshot";
    runtimeInputs = [
      fs
      hyprland
      jq
      coreutils
      libnotify
    ];
    text = ''
      target="''${1:?usage: shell-screenshot primary|secondary|all [copy|save]}"
      mode="''${2:-copy}"
      case "$target" in
        primary) name="${osConfig.my.monitors.primary}" ;;
        secondary) name="${osConfig.my.monitors.secondary}" ;;
        all) name="all" ;;
        *) echo "unknown target: $target" >&2; exit 2 ;;
      esac
      fail() { notify-send -a Screenshot -u normal "Screenshot failed" "$1" || true; exit 1; }

      # The Center closes before this runs: wait until its layer is gone (<=1 s), then past
      # Hyprland's 100 ms layer fade, so the panel is never in the shot.
      for _ in $(seq 20); do
        hyprctl -j layers | jq -e 'any(.[].levels[][]; .namespace == "qs-center")' >/dev/null || break
        sleep 0.05
      done
      sleep 0.15

      dir="$HOME/Pictures/Screenshots"
      mkdir -p "$dir"
      if [ "$target" = all ]; then id=all; else id="$target-$name"; fi
      file="$dir/$(date +%Y-%m-%d_%H-%M-%S)_$id.png"
      if [ "$mode" = save ]; then out=(-p "$file"); else out=(-c); fi

      if [ "$target" = all ]; then
        flameshot full "''${out[@]}" || fail "flameshot could not capture the screens"
      else
        # The same derivation as flameshot-screen: the position among the ACTIVE monitors by id.
        idx="$(hyprctl monitors -j | jq -r --arg t "$name" '
          ([ .[] | { name, id } ] | sort_by(.id) | map(.name) | index($t)) // empty')"
        [ -n "$idx" ] || fail "$name is not connected"
        flameshot screen --number "$idx" "''${out[@]}" || fail "flameshot could not capture $name"
      fi
    '';
  };

  # flameshot-cancel: Esc closes the picker and leaves the submap.
  flameshotCancel = writeShellApplication {
    name = "flameshot-cancel";
    runtimeInputs = [ hyprland ];
    text = ''
      hyprctl dispatch 'hl.dsp.window.close({ window = "title:flameshot" })' >/dev/null 2>&1 || true
      hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null 2>&1 || true
    '';
  };
in
{
  # v14 (unstable) plus the keyboard-flow scripts (called by the submap in keybinds.lua).
  home.packages = [
    fs
    flameshotScreenshot
    flameshotPick
    flameshotScreen
    flameshotCancel
    shellScreenshot
  ];

  # The screenshot aliases live next to the tool, not in zsh.nix (the eza/bat convention). They
  # take a monitor NAME (rule 11); 1 is the MAIN panel everywhere in this repo, never a position.
  programs.zsh.shellAliases = {
    screenshot = "flameshot gui"; # an interactive selection (it opens the v14 picker)
    scfull = "flameshot full -c"; # both screens, to the clipboard
    sc1 = "flameshot-screen ${osConfig.my.monitors.primary}"; # the main one, to the clipboard
    sc2 = "flameshot-screen ${osConfig.my.monitors.secondary}"; # the secondary, to the clipboard
  };

  # Flameshot does not create the output folder reliably on its own.
  home.file."Pictures/Screenshots/.keep".text = "";

  xdg.configFile."flameshot/flameshot.ini".text = ''
    [General]
    disabledTrayIcon=true
    showStartupLaunchMessage=false
    showDesktopNotification=true
    savePath=${config.home.homeDirectory}/Pictures/Screenshots
    savePathFixed=true
    saveAsFileExtension=.png
    contrastOpacity=128
    showHelp=false
    drawColor=#${p.red}
    drawThickness=3
    uiColor=#${p.purple}
    userColors=picker, ${lib.concatMapStringsSep ", " (k: "#${p.${k}}") penColors}
  '';
}
