# Vicinae extensions: six from the pinned vicinaehq/extensions input, built offline from their
# lockfiles, and my own ./repositories. Why these, and how the tokens arrive: docs/notes/desktop/vicinae.md
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs) importNpmLock playerctl pulseaudio;

  src = name: "${inputs.vicinae-extensions}/extensions/${name}";

  # importNpmLock reads each package-lock.json, so a bump of the input needs no hash edit here.
  mk =
    name: attrs:
    (config.lib.vicinae.mkExtension {
      inherit name;
      src = src name;
    }).overrideAttrs
      ({ npmFlags = [ "--legacy-peer-deps" ]; } // attrs);

  # dbus-next's OPTIONAL usocket pins node-gyp 7, which dies on Node 24 (upstream skips these two
  # for it). It goes from the lock; dbus-next then uses plain path sockets, all the buses need.
  withoutUsocket =
    name:
    let
      lock = lib.importJSON "${src name}/package-lock.json";
    in
    {
      npmDeps = importNpmLock {
        npmRoot = src name;
        packageLock = lock // {
          packages = lib.mapAttrs (
            _: m:
            m
            // lib.optionalAttrs (m ? optionalDependencies) {
              optionalDependencies = removeAttrs m.optionalDependencies [ "usocket" ];
            }
          ) (removeAttrs lock.packages [ "node_modules/usocket" ]);
        };
      };
    };
in
{
  programs.vicinae.extensions = [
    (mk "nix" { }) # nixpkgs packages and options, Home Manager options
    (mk "systemd" (withoutUsocket "systemd")) # list, start, stop and restart units
    (mk "bluetooth" (withoutUsocket "bluetooth")) # power, scan, connect; Blueman stays as the pairing agent
    (mk "github" { }) # issues, PRs, workflow runs; its token rides VICINAE_OVERRIDES (default.nix)
    # Media and volume. Both shell out to a CLI by bare name; pinned here so neither rides PATH.
    (mk "player-pilot" {
      postPatch = ''
        substituteInPlace src/utils/playerctl.ts \
          --replace-fail '`playerctl ' '`${lib.getExe playerctl} ' \
          --replace-fail '"playerctl --list-all"' '"${lib.getExe playerctl} --list-all"'
      '';
    })
    (mk "pulseaudio" {
      # pactl from pulseaudio only as the client: PipeWire's pipewire-pulse is the server.
      postPatch = ''
        substituteInPlace src/pactl.ts \
          --replace-fail '?? "pactl"' '?? "${lib.getExe' pulseaudio "pactl"}"'
      '';
    })
    # Mine, not from the input: my GitHub accounts and FAI's GitLab in one list.
    (config.lib.vicinae.mkExtension {
      name = "repositories";
      src = ./repositories;
    })
  ];
}
