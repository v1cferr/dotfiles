# OBS STUDIO: recording and streaming scenes, through Home Manager's module (idiomatic).
# Capture is the PipeWire portal source (dmabuf, GPU side); encoding is QSV on the Arc. No note: this is all of it.
{
  config,
  osConfig,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    gawk
    jq
    obs-studio
    symlinkJoin
    writeShellApplication
    ;
  inherit (pkgs.obs-studio-plugins) obs-pipewire-audio-capture;
  # hyprctl from the RUNNING compositor (unstable), never the stable one a bare pkgs.hyprland is.
  hyprland = osConfig.programs.hyprland.package;

  recordings = "${config.home.homeDirectory}/Videos/Recordings"; # the folder screenrec.nix keeps

  # obs-sync-profile: OBS rewrites basic.ini on exit, so a store file would fight it; instead each
  # launch patches the keys below into every profile and leaves the rest to the UI.
  # Video follows the primary monitor LIVE: its resolution with no downscale, and its refresh as an
  # exact fraction (179.999 Hz = 179999/1000). The secondary only shows the OBS window.
  syncProfile = writeShellApplication {
    name = "obs-sync-profile";
    runtimeInputs = [
      hyprland
      jq
      gawk
    ];
    text = ''
      # Recording: QSV on the Arc, "Small" quality (constant QP, so no bitrate to size), next to
      # the wl-screenrec clips. "Section Key=Value", one per line.
      sets="SimpleOutput RecEncoder=qsv
      SimpleOutput RecQuality=Small
      SimpleOutput RecFormat2=hybrid_mp4
      SimpleOutput FilePath=${recordings}"
      if mon="$(hyprctl monitors -j 2>/dev/null \
        | jq -ec --arg n "${osConfig.my.monitors.primary}" '.[] | select(.name == $n)')"; then
        w="$(jq -r .width <<<"$mon")"
        h="$(jq -r .height <<<"$mon")"
        num="$(jq -r '.refreshRate * 1000 | round' <<<"$mon")"
        sets="$sets
      Video BaseCX=$w
      Video BaseCY=$h
      Video OutputCX=$w
      Video OutputCY=$h
      Video FPSType=2
      Video FPSNum=$num
      Video FPSDen=1000"
      fi # no Hyprland or the monitor is off: the video keys stay as they were
      for ini in "''${XDG_CONFIG_HOME:-$HOME/.config}"/obs-studio/basic/profiles/*/basic.ini; do
        [ -f "$ini" ] || continue
        # Replaces or adds each key inside its section (adding the section if missing).
        awk -v sets="$sets" '
          BEGIN {
            n = split(sets, line, "\n")
            for (i = 1; i <= n; i++) {
              sp = index(line[i], " "); sec = substr(line[i], 1, sp - 1); kv = substr(line[i], sp + 1)
              want[sec] = want[sec] kv "\n"; drop[sec, substr(kv, 1, index(kv, "=") - 1)] = 1
            }
          }
          function flush() { if (cur in want) { printf "%s", want[cur]; done[cur] = 1 } }
          /^\[.*\]$/ { flush(); cur = substr($0, 2, length($0) - 2); print; next }
          { eq = index($0, "="); if (eq && ((cur, substr($0, 1, eq - 1)) in drop)) next; print }
          END { flush(); for (sec in want) if (!(sec in done)) { print ""; print "[" sec "]"; printf "%s", want[sec] } }
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
      ${syncProfile}/bin/obs-sync-profile || true
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
      obs-pipewire-audio-capture # per-app audio sources (Discord apart from the game, say)
    ];
  };

  # The portal (xdph) caps a capture at 120 fps by default, so 180 Hz would be recorded at 120;
  # 0 follows the output's own refresh. The token box comes pre-ticked, so picking the primary once
  # in OBS's PipeWire source is remembered in the scene (no picker on the next launch).
  xdg.configFile."hypr/xdph.conf".text = ''
    screencopy {
      max_fps = 0
      allow_token_by_default = true
    }
  '';
}
