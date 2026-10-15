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
  inherit (pkgs) importNpmLock pulseaudio;

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
    (mk "vscode-recents" { }) # VS Code's File > Open Recent list, read from its state.vscdb
    # Audio devices and per-app volume. It runs pactl by bare name, so it is pinned here; pactl
    # comes from pulseaudio only as the client, PipeWire's pipewire-pulse is the server.
    (mk "pulseaudio" {
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
