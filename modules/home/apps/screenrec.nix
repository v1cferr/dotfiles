# SCREEN RECORDING: wl-screenrec (wlr-screencopy plus VA-API on the Arc) with a keyboard flow,
# the Flameshot submap for video. Why this tool and its limits: docs/notes/apps/screenrec.md
{
  config,
  osConfig,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    coreutils
    ffmpeg
    jq
    libnotify
    procps
    slurp
    unstable # the CHANNEL and not a package, so `unstable.x` stays greppable at each use site
    writeShellApplication
    xdg-utils
    ;
  # hyprctl from the RUNNING compositor (unstable), never the stable 0.55 a bare pkgs.hyprland is.
  hyprland = osConfig.programs.hyprland.package;

  # 0.3.2: the stable 0.2.0 crashes on a rotated output (DP-2) with a broken filter graph.
  wlScreenrec = unstable.wl-screenrec;

  p = config.my.theme.palette; # SSOT: modules/home/desktop/palette.nix (rule 11, decision 0001)
  dir = "${config.home.homeDirectory}/Videos/Recordings";

  # The interactive shell exports alsa/pipewire built on a newer glibc, which breaks ffmpeg-linked
  # binaries from the store when a script runs from the terminal (the keybind path is clean).
  cleanEnv = "unset LD_LIBRARY_PATH";

  # togif: an MP4 into a GIF next to it, one-pass palette (15 fps, the LONGER side at most 960 px,
  # so the portrait DP-2 does not come out 1707 px tall).
  toGif = writeShellApplication {
    name = "togif";
    runtimeInputs = [
      ffmpeg
      libnotify
    ];
    text = ''
      ${cleanEnv}
      in="''${1:?usage: togif <file.mp4>}"
      out="''${in%.*}.gif"
      filters="fps=15,scale='min(960,iw)':'min(960,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2:flags=lanczos"
      if ffmpeg -v error -y -i "$in" \
        -vf "$filters,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a" \
        "$out"; then
        notify-send -a Recording "GIF ready" "$out" || true
      else
        notify-send -a Recording -u normal "GIF failed" "$in" || true
        exit 1
      fi
    '';
  };

  # screenrec-start: records ONE monitor (by name, rule 11) or a slurp region, in the background.
  # The PID and the file live in $XDG_RUNTIME_DIR, which is how screenrec-toggle knows to stop.
  screenrecStart = writeShellApplication {
    name = "screenrec-start";
    runtimeInputs = [
      wlScreenrec
      slurp
      hyprland
      jq
      coreutils
      libnotify
    ];
    text = ''
      ${cleanEnv}
      target="''${1:?usage: screenrec-start primary|secondary|region}"
      state="''${XDG_RUNTIME_DIR:-/tmp}/screenrec"
      hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null 2>&1 || true
      fail() { hyprctl notify -1 2500 "rgb(${p.red})" "$1" >/dev/null 2>&1 || true; exit 1; }

      case "$target" in
        primary) name="${osConfig.my.monitors.primary}" ;;
        secondary) name="${osConfig.my.monitors.secondary}" ;;
        region) name="" ;;
        *) echo "unknown target: $target" >&2; exit 2 ;;
      esac

      if [ -n "$name" ]; then
        hyprctl monitors -j | jq -e --arg n "$name" 'any(.[]; .name == $n)' >/dev/null \
          || fail "$name is not connected"
        src=(-o "$name"); id="$target-$name"
      else
        geo="$(slurp)" || exit 0 # Esc in slurp = cancelled, not an error
        src=(-g "$geo"); id=region
      fi

      mkdir -p "${dir}"
      file="${dir}/$(date +%Y-%m-%d_%H-%M-%S)_$id.mp4"
      # --low-power=off: the Arc has no low-power H.264 entrypoint, so auto only adds a warning.
      wl-screenrec --low-power=off "''${src[@]}" -f "$file" >"$state.log" 2>&1 &
      pid=$!
      sleep 0.5
      # A region across two monitors is refused right away ("not entirely within one output").
      kill -0 "$pid" 2>/dev/null || fail "recording failed: $(tail -n1 "$state.log")"
      printf '%s\n%s\n' "$pid" "$file" >"$state"
      notify-send -a Recording -t 1500 "Recording" "SUPER+SHIFT+R stops" || true
    '';
  };

  # screenrec-toggle: stops a running recording (SIGINT closes the MP4 cleanly) and offers the
  # GIF; with nothing running it enters the submap that picks what to record.
  screenrecToggle = writeShellApplication {
    name = "screenrec-toggle";
    runtimeInputs = [
      hyprland
      coreutils
      procps
      libnotify
      xdg-utils
      toGif
    ];
    text = ''
      ${cleanEnv}
      state="''${XDG_RUNTIME_DIR:-/tmp}/screenrec"
      if [ -f "$state" ]; then
        { read -r pid; read -r file; } <"$state"
        rm -f "$state"
        if kill -0 "$pid" 2>/dev/null; then
          kill -INT "$pid"
          while kill -0 "$pid" 2>/dev/null; do sleep 0.1; done
          # Detached: notify-send -A blocks until the card is clicked or dismissed.
          (
            act="$(notify-send -a Recording "Recording saved" "$(basename "$file")" \
              -A open="Open folder" -A gif="Convert to GIF")" || true
            case "$act" in
              open) xdg-open "$(dirname "$file")" ;;
              gif) togif "$file" ;;
            esac
          ) >/dev/null 2>&1 &
          exit 0
        fi
      fi
      hyprctl dispatch 'hl.dsp.submap("screenrec")' >/dev/null 2>&1 || true
    '';
  };
in
{
  home.packages = [
    wlScreenrec
    screenrecStart
    screenrecToggle
    toGif
  ];

  home.file."Videos/Recordings/.keep".text = "";
}
