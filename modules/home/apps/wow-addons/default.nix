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
  # The bundle the last switch copied, so a new one is compared by content (see the activation).
  lastBundle = "${config.xdg.stateHome}/wow-addons/bundle";

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
  #
  # The NTFS mount has `acl`, so it KEEPS unix modes, and rsync hands new files the store's
  # read-only ones: removing Bagnon then failed with "Permission denied" (06/11/2026). `writable`
  # gives the owner write back before any delete, and --chmod keeps new copies writable.
  #
  # Every store file has mtime 1, so rsync's size+mtime check skipped any edit that kept the size:
  # Questie 12.9.0 kept its old 1858-byte HBDHooks.lua and failed to load a library (14/11/2026),
  # with 38 more stale files. A new bundle is therefore compared by checksum (~25 s over NTFS).
  home.activation.wowAddons = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Only what lacks it: a chmod -R over 2 GiB of NTFS on every switch would cost for nothing.
    writable() { [ ! -e "$1" ] || run find "$1" ! -perm -u+w -exec chmod u+w {} +; }
    if [ ! -d ${lib.escapeShellArg addonDir} ]; then
      echo "wow-addons: ${addonDir} is missing (Windows disk not mounted?), skipped." >&2
    else
      run mkdir -p ${lib.escapeShellArg (builtins.dirOf manifest)}
      if [ -f ${lib.escapeShellArg manifest} ]; then
        while IFS= read -r folder; do
          if [ -n "$folder" ] && [ ! -e ${wow-addons}/"$folder" ]; then
            writable ${lib.escapeShellArg addonDir}/"$folder"
            run rm -rf ${lib.escapeShellArg addonDir}/"$folder"
          fi
        done < ${lib.escapeShellArg manifest}
      fi
      byContent=()
      [ "$(cat ${lib.escapeShellArg lastBundle} 2>/dev/null)" = ${wow-addons} ] || byContent=(--checksum)
      for dir in ${wow-addons}/*/; do
        folder=$(basename "$dir")
        writable ${lib.escapeShellArg addonDir}/"$folder"
        run ${lib.getExe rsync} -rt "''${byContent[@]}" --delete --no-perms --no-owner --no-group \
          --chmod=Du+w,Fu+w "$dir" ${lib.escapeShellArg addonDir}/"$folder"/
      done
      if [ ! -v DRY_RUN ]; then
        ls ${wow-addons} > ${lib.escapeShellArg manifest}
        echo ${wow-addons} > ${lib.escapeShellArg lastBundle}
      fi
    fi
  '';
}
