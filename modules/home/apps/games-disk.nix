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
      description = "The games folder: the Windows disk on the desk, a plain folder elsewhere.";
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
    # WoW is the one game every host that plays has, so its link lives here; a host's other
    # games, and its saves, are its own list (hosts/<host>/games.nix). The key is where the
    # LAUNCHER looks and must not change: Battle.net already knows the game at that path.
    my.games.linked.".local/share/bottles/bottles/Battlenet/drive_c/Program Files (x86)/World of Warcraft" =
      "World of Warcraft";

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
