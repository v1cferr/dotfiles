# THE OLD ARCH ARCHIVE, the SYSTEM side: the mountpoint plus the path's SSOT (rule 11).
# What MOUNTS it is home/services/arch-legacy-mount.nix. The whole story: docs/notes/arch-legacy.md
{ config, lib, ... }:

{
  options.my.archAntigo = {
    local = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/arch-antigo";
      description = "The mountpoint. An SSOT read by the mount's unit and by Dolphin's bookmark (rule 11).";
    };

    repo = lib.mkOption {
      type = lib.types.str;
      default = "rclone:gdrive:BACKUPS_EX-B560M-V5/ARCH-KINGSTON";
      description = ''
        The archive's restic repo. `rclone:<remote>:<path>`: restic brings up an
        `rclone serve restic --stdio` and talks to it. The folder on the Drive was
        called `KINGSTON` and became `ARCH-KINGSTON` on 05/08/2026 (the old name did
        not say it was the Arch).
      '';
    };
  };

  # OUTSIDE /home on purpose: inside it, the user's FUSE would enter the backup's `paths` and
  # make restic exit 3, which stops the `forget --prune`. See docs/notes/restic.md
  config = lib.mkIf config.my.services.arch-antigo-mount {
    systemd.tmpfiles.rules = [
      "d ${config.my.archAntigo.local} 0755 v1cferr users -" # the owner is the user: they are the one who mounts
    ];
  };
}
