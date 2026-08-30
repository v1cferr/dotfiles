# v14 plus the keyboard-flow scripts, called by the submap in keybinds.lua.
{
  config,
  pkgs,
  inputs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    coreutils
    hyprland
    jq
    unstable # the CHANNEL and not a package, so `unstable.x` stays greppable at each use site
    writeShellApplication
    ;

  # The Quickshell package (a flake input), bound once because the path repeats below.
  qsPkg = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
  fs = unstable.flameshot; # v14

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
  # monitors' physical order, so it survives a turned-off TV or a rearrangement.
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
      if [ -z "$info" ]; then reset; exit 0; fi  # the target is not active (a turned-off TV, say)
      read -r i n <<<"$info"

      # the preview's center: slice i horizontally, 55% of the height.
      cx=$(( px + pw * (2 * i + 1) / (2 * n) ))
      cy=$(( py + ph * 55 / 100 ))
      hyprctl dispatch "hl.dsp.cursor.move({ x = $cx, y = $cy })" >/dev/null 2>&1 || true
      hyprctl dispatch 'hl.dsp.send_shortcut({ mods = 0, key = "mouse:272", window = "title:flameshot" })' >/dev/null 2>&1 || true
      reset
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
    flameshotCancel
  ];

  # The screenshot aliases live next to the tool, not in zsh.nix (the eza/bat convention).
  # `--number` is a Qt index and NOT a monitor name: if the layout changes, MEASURE AGAIN.
  programs.zsh.shellAliases = {
    screenshot = "flameshot gui"; # an interactive selection (it opens the v14 picker)
    scfull = "flameshot full -c"; # both screens, to the clipboard
    sc1 = "flameshot screen --number 1 -c"; # the TV (HDMI-A-3), to the clipboard
    sc2 = "flameshot screen --number 0 -c"; # the main one (DP-2), to the clipboard
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
    drawColor=#ff0000
    drawThickness=3
    uiColor=#${config.my.theme.palette.purple}
  '';
}
