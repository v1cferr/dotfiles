# THE OLD ARCH ARCHIVE, the SYSTEM side: the mountpoint plus the path's SSOT (rule 11).
# What MOUNTS it is the home side. The whole story: docs/notes/boot-and-storage/arch-legacy.md
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
      default = "/mnt/seagate-old/restic-arch-kingston";
      description = ''
        The archive's restic repo: a LOCAL path on the Seagate since 24/09/2026. It lived on the
        Drive as `rclone:gdrive:BACKUPS_EX-B560M-V5/ARCH-KINGSTON` (renamed from `KINGSTON` on
        05/08/2026, because the old name did not say it was the Arch) until the account blew past
        its 15 GiB quota. Local, the mount costs no quota and needs no network.
      '';
    };
  };

  # OUTSIDE /home on purpose: inside it, the user's FUSE would have entered the daily backup's
  # `paths` and made restic exit 3, stopping the `forget --prune`. That backup is gone since
  # 24/09/2026, but the lesson outlived it: docs/notes/boot-and-storage/restic.md
  config = lib.mkIf config.my.services.arch-antigo-mount {
    systemd.tmpfiles.rules = [
      "d ${config.my.archAntigo.local} 0755 v1cferr users -" # the owner is the user: they are the one who mounts
    ];
  };
}
