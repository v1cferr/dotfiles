# HOME SUBVOLUMES: the paths that churn (VM images, game libraries) as nested btrfs subvolumes, so
# btrbk's hourly @home snapshots stop at them. Why, and the 24/10 numbers: docs/notes/boot-and-storage/disk-hygiene.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    btrfs-progs
    coreutils
    e2fsprogs
    findutils
    gnugrep
    util-linux
    writeShellApplication
    ;

  cfg = config.my.disk.subvolumes;

  convert = writeShellApplication {
    name = "convert-to-subvolume";
    runtimeInputs = [
      btrfs-progs
      coreutils
      e2fsprogs # lsattr/chattr: the +C flag has to be carried over by hand
      findutils
      gnugrep
      util-linux # findmnt
    ];
    text = builtins.readFile ./scripts/convert-to-subvolume.sh;
  };
in
{
  options.my.disk.subvolumes = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Paths under $HOME that must be their own btrfs subvolume (out of the snapshots).";
  };

  config = {
    my.disk.subvolumes = [
      # The WHOLE library and not `common`: Steam downloads into `steamapps/downloading` and renames
      # into `common`, and a rename across a subvolume boundary fails with EXDEV.
      ".local/share/Steam/steamapps"
      "Projects/Local/macos-arm64-lab/state" # the macOS lab VM images, rewritten every session
      ".local/share/bottles/bottles/Battlenet/drive_c/Program Files (x86)/Overwatch" # made by hand on 18/10
    ];

    home.packages = [ convert ];

    # CREATE, NEVER CONVERT: a missing path becomes a subvolume (as the user, so the ownership is
    # right, which a root tmpfiles `v` would not give the parents). An existing plain directory is
    # only reported, because converting it means copying live data and that is a deliberate act.
    home.activation.homeSubvolumes = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      lib.concatMapStrings (rel: ''
        p=${lib.escapeShellArg "${config.home.homeDirectory}/${rel}"}
        if [ "$(${coreutils}/bin/stat -f -c %T "$HOME")" = btrfs ]; then
          if [ ! -e "$p" ]; then
            run ${coreutils}/bin/mkdir -p "$(${coreutils}/bin/dirname "$p")"
            run ${btrfs-progs}/bin/btrfs subvolume create "$p" >/dev/null
          elif [ "$(${coreutils}/bin/stat -c %i "$p")" != 256 ]; then
            warnEcho "$p is a plain directory, so the snapshots pin it: convert-to-subvolume ${lib.escapeShellArg rel}"
          fi
        fi
      '') cfg
    );
  };
}
