# WOW FOREVER ADD-ONS: pkgs/wow-addons copied into the game's AddOns folder on every switch.
# Why Nix and not an add-on manager, and how to add one: docs/notes/apps/wow-addons.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    bitwarden-cli
    git
    jq
    rsync
    sops
    wow-addons
    writeShellApplication
    ;

  addonDir = "${config.my.games.root}/World of Warcraft/_forever_/Interface/AddOns";
  # What the last switch put there, so an add-on that leaves the list is removed too.
  manifest = "${config.xdg.stateHome}/wow-addons/managed";

  # `wow-addons-key`: the CurseForge key in one go (Bitwarden, index, sync-secrets, bump, switch).
  wow-addons-key = writeShellApplication {
    name = "wow-addons-key";
    runtimeInputs = [
      bitwarden-cli
      git
      jq
      sops # sync-secrets wants it on PATH, outside the devShell too
    ];
    text = builtins.readFile ./scripts/wow-addons-key.sh; # bash in its own file = shellcheck at build time
  };
in
{
  home.packages = [ wow-addons-key ];

  # COPIES, not store symlinks: the folder is on NTFS and Windows plays from it too. Folders Nix
  # never managed (anything installed by hand) are left alone.
  home.activation.wowAddons = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d ${lib.escapeShellArg addonDir} ]; then
      echo "wow-addons: ${addonDir} is missing (Windows disk not mounted?), skipped." >&2
    else
      run mkdir -p ${lib.escapeShellArg (builtins.dirOf manifest)}
      if [ -f ${lib.escapeShellArg manifest} ]; then
        while IFS= read -r folder; do
          if [ -n "$folder" ] && [ ! -e ${wow-addons}/"$folder" ]; then
            run rm -rf ${lib.escapeShellArg addonDir}/"$folder"
          fi
        done < ${lib.escapeShellArg manifest}
      fi
      for dir in ${wow-addons}/*/; do
        folder=$(basename "$dir")
        run ${lib.getExe rsync} -rt --delete --no-perms --no-owner --no-group \
          "$dir" ${lib.escapeShellArg addonDir}/"$folder"/
      done
      [ -v DRY_RUN ] || ls ${wow-addons} > ${lib.escapeShellArg manifest}
    fi
  '';
}
