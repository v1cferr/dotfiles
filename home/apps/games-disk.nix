# GAMES ON THE WINDOWS DISK: the heavy game data lives on /mnt/windows (NTFS, shared with Windows
# 11) and is symlinked back into the place each launcher already looks.
# Why symlink instead of relocating: docs/notes/boot-and-storage/games-disk.md
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
      # Diablo IV. VERIFIED on 31/08 before deleting the local copy: 1183 files, zero size
      # mismatches, the only difference being CASC indices that the agent regenerates.
      ".local/share/bottles/bottles/Battlenet/drive_c/Program Files (x86)/Diablo IV" = "Diablo IV";

      # Uncharted 3, read by RPCS3 through `~/.config/rpcs3/games.yml`, which keeps working
      # untouched precisely because the symlink sits at the old path. VERIFIED byte for byte:
      # sha256 9c600ebb6ed8a13a5c7332fa56378a9f04f98405de4bf2e0bd06b8ab31b804b2 on both disks.
      #
      # The FILE and not the `PS3` folder: linking the folder would drop the sibling
      # `Vimm's Lair.txt`, and copying that over is a write to NTFS this pass deliberately avoids.
      "Games/PS3/Uncharted 3 - Drake's Deception (USA, Canada) (En,Fr,Es,Pt).dec.iso" =
        "PS3/Uncharted 3 - Drake's Deception (USA, Canada) (En,Fr,Es,Pt).dec.iso";

      # COPIED on 03/09, not deduplicated: these four had no counterpart on the Windows disk, or
      # had a STALE one. Overwatch is the stale case, and it is why every one of these was checked
      # file by file (path and size) after the rsync and not merely by total: its Windows copy read
      # 74 GiB against 76 here and would have passed an eyeball, while 68.9 GiB of it differed.
      ".local/share/bottles/bottles/Battlenet/drive_c/Program Files (x86)/Overwatch" = "Overwatch";
      ".local/share/bottles/bottles/Battlenet/drive_c/Program Files (x86)/Hearthstone" = "Hearthstone";

      # The GAME folder only, never the bottle. A Wine prefix on NTFS does not survive (no unix
      # permissions, no symlinks, no case sensitivity), and it does not need to: after this the
      # three prefixes together weigh 8.4 GiB, down from 225.
      #
      # The CS2 saves are IRREPLACEABLE (a repack, so no Steam cloud) and live in
      # `drive_c/users/...`, a different tree from `drive_c/Games`, so this move does not touch
      # them. Verified before and after: 40 files, 1.3 GiB, matching the restic mirror that
      # home/services/cs2-saves-backup.nix maintains.
      ".local/share/bottles/bottles/Cities-Skylines-II/drive_c/Games/Cities - Skylines II" =
        "Cities - Skylines II";
      ".local/share/bottles/bottles/Ascension/drive_c/Program Files/Ascension Launcher" =
        "Ascension Launcher";

      # NEVER duplicated, unlike everything above: the repack installed it straight onto the
      # Windows disk on 25/08 and the Kingston has never held a copy. The `Black-Flag` bottle was
      # created EMPTY for this game alone (DX12 through vkd3d, which the Battle.net one does not
      # need), so the 67 GiB stay exactly where they already were.
      ".local/share/bottles/bottles/Black-Flag/drive_c/Games/Assassin Creed Black Flag Resynced" =
        "Assassin Creed Black Flag Resynced";

      # NEVER duplicated either, and for the simplest reason there is: the archive was extracted
      # straight into /mnt/windows/Games on 07/09, so these 56 GiB have never been on the Kingston.
      ".local/share/bottles/bottles/Bodycam/drive_c/Games/Bodycam" = "Bodycam";

      # NEVER duplicated either, same as the two above: the repack was installed straight onto the
      # Windows disk on 29/08 and only got a bottle on 12/09, so these 16 GiB never moved at all.
      ".local/share/bottles/bottles/Victoria-3/drive_c/Games/Victoria 3" = "Victoria 3";
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
      # NOT IN RESTIC, and nothing here changes that: `paths` is /home/v1cferr with
      # `.local/share/bottles` excluded, so the off-machine copy is OneDrive, which only syncs
      # when Windows is the one running. One 19 MiB ironman save, accepted knowingly.
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
