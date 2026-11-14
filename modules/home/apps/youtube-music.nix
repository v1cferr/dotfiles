# Pear Desktop: the YouTube Music client, seen by the shell through its own MPRIS player.
# Why unstable, why no wrapper and why the plugin is on: docs/notes/apps/pear-desktop.md
{ lib, pkgs, ... }:

let
  inherit (pkgs) jq writeText;

  # The ONLY keys Nix owns in the app's own config.json; the app keeps writing everything else.
  want = {
    options.autoUpdates = false; # Nix updates it; the in-app check is inert outside AppImage anyway
    plugins.shortcuts.enabled = true; # this plugin is what registers Pear's own MPRIS player
  };
  wantJson = builtins.toJSON want;
  seed = writeText "pear-desktop-config.json" wantJson;
in
{
  home.packages = [ pkgs.unstable.pear-desktop ]; # stable lags a release (3.11 against 3.12)

  # A merge, not a file: the app rewrites config.json at runtime (rule 14). Idempotent, and a file
  # it cannot parse is left alone with a warning instead of being replaced.
  home.activation.pearDesktopConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfg="''${XDG_CONFIG_HOME:-$HOME/.config}/YouTube Music/config.json"
    if [ ! -e "$cfg" ]; then
      run install -Dm600 ${seed} "$cfg"
    elif ! ${lib.getExe jq} -e '.options.autoUpdates == false and .plugins.shortcuts.enabled == true' "$cfg" >/dev/null 2>&1; then
      if merged=$(${lib.getExe jq} --argjson want '${wantJson}' '. * $want' "$cfg" 2>/dev/null); then
        run install -m600 /dev/stdin "$cfg" <<<"$merged"
      else
        warnEcho "Pear Desktop: $cfg is not valid JSON, left as is (the MPRIS plugin stays as the app has it)"
      fi
    fi
  '';
}
