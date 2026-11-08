# OBS STUDIO: recording and streaming scenes, through Home Manager's module (idiomatic).
# Screen capture goes through the portal (PipeWire) and the Arc encoders are built in. No note: this is all of it.
{ osConfig, pkgs, ... }:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    gawk
    jq
    obs-studio
    symlinkJoin
    writeShellApplication
    ;
  inherit (pkgs.obs-studio-plugins)
    obs-pipewire-audio-capture
    wlrobs
    ;
  # hyprctl from the RUNNING compositor (unstable), never the stable one a bare pkgs.hyprland is.
  hyprland = osConfig.programs.hyprland.package;

  # obs-sync-fps: every profile's FPS becomes the primary monitor's live refresh rate, as an exact
  # fraction (179.999 Hz = 179999/1000). OBS rewrites basic.ini on exit, so this runs at each launch.
  syncFps = writeShellApplication {
    name = "obs-sync-fps";
    runtimeInputs = [
      hyprland
      jq
      gawk
    ];
    text = ''
      rate="$(hyprctl monitors -j 2>/dev/null \
        | jq -er --arg n "${osConfig.my.monitors.primary}" '.[] | select(.name == $n) | .refreshRate')" \
        || exit 0 # no Hyprland or the monitor is off: OBS opens with what it had
      num="$(awk -v r="$rate" 'BEGIN { printf "%d", r * 1000 + 0.5 }')"
      for ini in "''${XDG_CONFIG_HOME:-$HOME/.config}"/obs-studio/basic/profiles/*/basic.ini; do
        [ -f "$ini" ] || continue
        # Sets the three keys inside [Video], replacing or adding them, and leaves the rest untouched.
        awk -v num="$num" '
          function flush() { if (video) { print "FPSType=2"; print "FPSNum=" num; print "FPSDen=1000" } video = 0 }
          /^\[/ { flush(); if ($0 == "[Video]") video = 1; print; next }
          video && /^(FPSType|FPSNum|FPSDen)=/ { next }
          { print }
          END { flush() }
        ' "$ini" >"$ini.tmp" && mv "$ini.tmp" "$ini"
      done
    '';
  };

  # The `obs` binary runs the sync first, so both the launcher and the terminal pick it up.
  # wrapOBS (programs.obs-studio) wraps THIS bin/obs, so the plugin env still reaches OBS.
  obsWithSync = symlinkJoin {
    inherit (obs-studio) name meta passthru;
    paths = [ obs-studio ];
    postBuild = ''
      rm "$out/bin/obs"
      cat >"$out/bin/obs" <<EOF
      #!${pkgs.runtimeShell}
      ${syncFps}/bin/obs-sync-fps || true
      exec ${obs-studio}/bin/obs "\$@"
      EOF
      chmod +x "$out/bin/obs"
    '';
  };
in
{
  programs.obs-studio = {
    enable = true;
    package = obsWithSync;
    plugins = [
      wlrobs # a wlr-screencopy source: one Hyprland output with no portal picker each time
      obs-pipewire-audio-capture # per-app audio sources (Discord apart from the game, say)
    ];
  };
}
