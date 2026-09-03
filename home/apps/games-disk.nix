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
    };

    # mkOutOfStoreSymlink and NOT a plain `source`: the target is MUTABLE game data that the
    # launcher patches in place. Copying it into the store would be absurd (89 GiB) and read-only.
    home.file = lib.mapAttrs (_name: target: {
      source = mkOutOfStoreSymlink "${cfg.root}/${target}";
    }) cfg.linked;
  };
}
