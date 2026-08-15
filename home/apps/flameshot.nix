# Flameshot (screenshots): v14 from the UNSTABLE channel (pkgs.unstable.*, through flake.nix's
# overlay) plus the config and the keyboard-flow scripts, in home (rule 4). The binds
# (Print / SUPER+SHIFT+S plus the "screenshot" submap) live in
# home/desktop/hypr/lua/keybinds.lua.
#
# Capture goes through xdg-desktop-portal (org.freedesktop.portal.Screenshot), served by
# xdg-desktop-portal-wlr (system/desktop/desktop.nix; the -hyprland one only DECLARES the
# interface, it does not implement it). With no direct grim and no useGrimAdapter, there is no
# "grim ... GNOME" warning.
#
# THE KEYBOARD FLOW (parity with the Arch v14): v14 ALWAYS shows a monitor picker on a
# multi-monitor setup (there is no skipping it, not even with --region). The picker only accepts
# a mouse click, so SUPER+SHIFT+S opens the picker and enters a submap; 1/2 SYNTHESIZE the click
# on the right monitor's preview (cursor plus send_shortcut mouse:272). The flameshot window
# here has an EMPTY class plus the title "flameshot", so the selectors and the window rule
# (rules.lua) use the title.
#
# NB: the .ini comes from /nix/store (read-only), so changes through the GUI do NOT persist;
# edit here and rebuild. Qt QSettings does NOT accept an inline comment in the .ini.
{
  config,
  pkgs,
  inputs,
  ...
}:

let
  # The Quickshell package (a flake input). Bound once because the full path goes past 130
  # columns and repeated itself in every consumer in this file.
  qsPkg = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
  fs = pkgs.unstable.flameshot; # v14

  # flameshot-screenshot: it opens the picker (flameshot gui) and ENTERS the "screenshot" submap
  # (the 1/2/Esc keys start counting). The watcher resets the submap when flameshot closes (a
  # mouse click on the picker, an internal Esc or a timeout), otherwise 1/2 would stay hijacked
  # afterwards. Entering and leaving the submap through `hyprctl dispatch` (the 0.55 Lua API).
  flameshotScreenshot = pkgs.writeShellApplication {
    name = "flameshot-screenshot";
    # `qs`: it hides the bar while the overlay exists (see below). runtimeInputs is mandatory,
    # since writeShellApplication uses a restricted PATH, not the user's.
    runtimeInputs = [
      fs
      pkgs.hyprland
      pkgs.jq
      pkgs.coreutils
      qsPkg
    ];
    text = ''
      flameshot gui >/dev/null 2>&1 &
      hyprctl dispatch 'hl.dsp.submap("screenshot")' >/dev/null 2>&1 || true

      fs_open() { hyprctl clients -j | jq -e 'any(.[]; .title=="flameshot")' >/dev/null 2>&1; }
      (
        c=0; while [ "$c" -lt 15 ];  do sleep 0.2; fs_open && break;  c=$((c+1)); done  # wait for it to open (<=3s)
        # THE DUPLICATED BAR: by now the overlay's FROZEN frame has already been captured, with
        # the bar in it. Hiding the LIVE bar now kills the duplicate WITHOUT taking it out of the
        # shot. On Hyprland a normal window NEVER covers a `top` layer, and the bar lives in one;
        # there is no window rule to invert that (an open feature request,
        # hyprwm/Hyprland#4847), so hiding is the only path. It only hides if it actually opened,
        # otherwise the bar would disappear for nothing.
        fs_open && qs ipc call bar hide >/dev/null 2>&1 || true
        c=0; while [ "$c" -lt 300 ]; do fs_open || break; sleep 0.2;  c=$((c+1)); done  # wait for it to close (<=60s)
        qs ipc call bar unhide >/dev/null 2>&1 || true  # it ALWAYS comes back, the 60s timeout included
        hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null 2>&1 || true
      ) >/dev/null 2>&1 &
    '';
  };

  # flameshot-pick <monitor>: it picks a monitor in the v14 picker by SYNTHESIZING the click.
  # The previews sit side by side in PHYSICAL ORDER (monitors by X, left to right); it resolves
  # the target's slice dynamically (nothing hardcoded, so it survives a turned-off TV or a
  # rearrangement).
  flameshotPick = pkgs.writeShellApplication {
    name = "flameshot-pick";
    runtimeInputs = [
      pkgs.hyprland
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      target="''${1:?usage: flameshot-pick <monitor>}"
      reset() { hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null 2>&1 || true; }

      # the picker's geometry (the window titled "flameshot"); with no picker, just reset and exit.
      geo="$(hyprctl clients -j | jq -r '[.[] | select(.title=="flameshot")] | first
        | if . == null then empty else "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])" end')"
      if [ -z "$geo" ]; then reset; exit 0; fi
      read -r px py pw ph <<<"$geo"

      # the target's 0-based index in the left-to-right order of the ACTIVE monitors, plus the total n.
      info="$(hyprctl monitors -j | jq -r --arg t "$target" '
        ([ .[] | { name, x } ] | sort_by(.x)) as $m
        | ($m | map(.name) | index($t)) as $i
        | if $i == null then empty else "\($i) \($m | length)" end')"
      if [ -z "$info" ]; then reset; exit 0; fi  # the target is not active (a turned-off TV, say)
      read -r i n <<<"$info"

      # the preview's center: slice i horizontally, 55% of the height (over the preview).
      cx=$(( px + pw * (2 * i + 1) / (2 * n) ))
      cy=$(( py + ph * 55 / 100 ))
      hyprctl dispatch "hl.dsp.cursor.move({ x = $cx, y = $cy })" >/dev/null 2>&1 || true
      hyprctl dispatch 'hl.dsp.send_shortcut({ mods = 0, key = "mouse:272", window = "title:flameshot" })' >/dev/null 2>&1 || true
      reset
    '';
  };

  # flameshot-cancel: Esc in the submap closes the picker and leaves the submap.
  flameshotCancel = pkgs.writeShellApplication {
    name = "flameshot-cancel";
    runtimeInputs = [ pkgs.hyprland ];
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

  # ── The screenshot aliases, migrated from the Arch zsh ─────────────────────
  # They stay HERE, next to the tool, and not in home/shell/zsh.nix, the same convention as
  # eza/bat, which live in cli.nix (zsh.nix keeps only the shell/system ones).
  #
  # VERIFIED on this machine's v14/Wayland: only `gui` opens the monitor picker; `full` and
  # `screen --number` capture DIRECTLY, with no picker. Which means the Arch aliases still hold;
  # what does not hold is `--region`, which v14 ignores.
  #
  # The `--number` is a Qt screen index, NOT a monitor name, so it does not come out of
  # my.monitors (rule 11 does not apply: there is no way to derive it). The mapping was measured
  # by capturing both screens and comparing against the wallpapers: 0 = the main one (DP-2),
  # 1 = the TV (HDMI-A-3). If the monitor layout changes, MEASURE AGAIN.
  # The numbers inherited from Arch already match the screenshot submap (1=TV, 2=main).
  programs.zsh.shellAliases = {
    screenshot = "flameshot gui"; # an interactive selection (it opens the v14 picker)
    scfull = "flameshot full -c"; # both screens, to the clipboard
    sc1 = "flameshot screen --number 1 -c"; # the TV (HDMI-A-3), to the clipboard
    sc2 = "flameshot screen --number 0 -c"; # the main one (DP-2), to the clipboard
  };

  # The screenshots' output folder (flameshot does not create it reliably on its own).
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
