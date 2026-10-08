# GAMES ON THE WINDOWS DISK: heavy game data on /mnt/windows (NTFS), symlinked back into the
# path each launcher already looks. Why symlink: docs/notes/boot-and-storage/games-disk.md
{
  config,
  lib,
  ...
}:

let
  inherit (config.lib.file) mkOutOfStoreSymlink;

  cfg = config.my.games;
in
{
  options.my.games = {
    root = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/windows/Games";
      description = "The shared games folder on the Windows disk (see the host's fileSystems).";
    };
    linked = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "A path under $HOME mapped to a path under `root`. Each becomes a symlink.";
    };
    saves = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "A path under $HOME mapped to an ABSOLUTE path, for saves outside `root`.";
    };
  };

  config = {
    # SSOT (rule 11): this list is the ONLY place that says which game already moved. disk-insight
    # reads `root` from here rather than repeating the mount point.
    #
    # The key is where the LAUNCHER looks and must not change, because the two systems do not share
    # a Battle.net config, only the files. Relocating the game inside Battle.net would buy nothing
    # and cost a "locate the install" round through the UI.
    my.games.linked = {
      # COPIED on 03/09, not deduplicated: these four had no counterpart on the Windows disk, or
      # had a STALE one. Overwatch is the stale case, and it is why every one of these was checked
      # file by file (path and size) after the rsync and not merely by total: its Windows copy read
      # 74 GiB against 76 here and would have passed an eyeball, while 68.9 GiB of it differed.
      ".local/share/bottles/bottles/Battlenet/drive_c/Program Files (x86)/Overwatch" = "Overwatch";
      ".local/share/bottles/bottles/Battlenet/drive_c/Program Files (x86)/Hearthstone" = "Hearthstone";

      # COPIED on 08/10, same rsync and same path-and-size check: both had stayed in the prefix,
      # 86 GiB of `@home`, with no copy on the Windows disk. VERIFIED: 2214 and 500 files, zero
      # mismatches.
      ".local/share/bottles/bottles/Battlenet/drive_c/Program Files (x86)/World of Warcraft" =
        "World of Warcraft";
      ".local/share/bottles/bottles/Battlenet/drive_c/Program Files (x86)/Warcraft III" = "Warcraft III";

      # The GAME folder only, never the bottle. A Wine prefix on NTFS does not survive (no unix
      # permissions, no symlinks, no case sensitivity), and it does not need to: after this the
      # three prefixes together weigh 8.4 GiB, down from 225.
      #
      # The CS2 saves are IRREPLACEABLE (a repack, so no Steam cloud) and live in
      # `drive_c/users/...`, a different tree from `drive_c/Games`, so this move does not touch
      # them. Verified before and after: 40 files, 1.3 GiB, matching the rsync mirror that
      # modules/home/services/cs2-saves-backup.nix maintains.
      ".local/share/bottles/bottles/Cities-Skylines-II/drive_c/Games/Cities - Skylines II" =
        "Cities - Skylines II";

      # NEVER duplicated, unlike everything above: the repack installed it straight onto the
      # Windows disk on 25/08 and the Kingston has never held a copy. The `Black-Flag` bottle was
      # created EMPTY for this game alone (DX12 through vkd3d, which the Battle.net one does not
      # need), so the 67 GiB stay exactly where they already were.
      ".local/share/bottles/bottles/Black-Flag/drive_c/Games/Assassin Creed Black Flag Resynced" =
        "Assassin Creed Black Flag Resynced";

      # NEVER duplicated either, same as the two above: the repack was installed straight onto the
      # Windows disk on 29/08 and only got a bottle on 12/09, so these 16 GiB never moved at all.
      ".local/share/bottles/bottles/Victoria-3/drive_c/Games/Victoria 3" = "Victoria 3";

      # The first STEAM game here, COPIED on 08/10: Steam installed it into the only library it
      # knows, `@home`, on 06/10. The game folder alone; `compatdata` (the Proton prefix) stays on
      # btrfs for the same reason every bottle does.
      ".local/share/Steam/steamapps/common/Baldurs Gate 3" = "Baldurs Gate 3";
    };

    # SAVES ARE NOT UNDER `root`, which is why they need their own attrset: Paradox writes into
    # the Windows user profile, and on that install Documents is redirected into OneDrive.
    my.games.saves = {
      # `save games` ALONE and not the whole `Victoria 3` profile, which sits right beside it.
      # What is deliberately left out and why: `shadercache` is built against the graphics API in
      # use, DX11 native on Windows against DXVK here, so a shared one is stutter at best;
      # `pdx_settings.json` carries the resolution and the video adapter of the other system; and
      # `logs`, `crashes` and `dumps` are churn this repo keeps off NTFS on purpose. The cost is
      # the Continue button, which reads `continue_game.json`: the save loads from the menu.
      #
      # NEVER WAS IN THE BACKUP, and nothing here changes that: the daily restic's `paths` was
      # /home/v1cferr with `.local/share/bottles` excluded, and that backup is gone since
      # 24/09/2026. The off-machine copy is OneDrive, which only syncs when Windows is the one
      # running. One 19 MiB ironman save, accepted knowingly.
      ".local/share/bottles/bottles/Victoria-3/drive_c/users/steamuser/Documents/Paradox Interactive/Victoria 3/save games" =
        "/mnt/windows/Users/vfla1/OneDrive/Documentos/Paradox Interactive/Victoria 3/save games";
    };

    # mkOutOfStoreSymlink and NOT a plain `source`: the target is MUTABLE game data that the
    # launcher patches in place. Copying it into the store would be absurd (89 GiB) and read-only.
    home.file = lib.mkMerge [
      (lib.mapAttrs (_name: target: {
        source = mkOutOfStoreSymlink "${cfg.root}/${target}";
      }) cfg.linked)
      (lib.mapAttrs (_name: target: { source = mkOutOfStoreSymlink target; }) cfg.saves)
    ];
  };
}
