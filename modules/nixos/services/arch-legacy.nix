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
      default = "${config.users.users.v1cferr.home}/Archive/restic-arch-kingston";
      description = ''
        The archive's restic repo, on the NVMe since 03/10/2026, when the Seagate it lived on was
        reformatted to hold the backup. Before that: the Seagate from 24/09/2026, and the Drive.
      '';
    };
  };

  # OUTSIDE /home on purpose: inside it, the user's FUSE would have entered the daily backup's
  # `paths` and made restic exit 3, stopping the `forget --prune`. That backup is gone since
  # 24/09/2026, but the lesson outlived it: docs/notes/boot-and-storage/restic.md
  config = lib.mkMerge [
    # Its second copy lives INSIDE the backup repo (`restic copy`, tagged `archive`), so backing
    # up these already-encrypted packs again would only store them twice.
    { my.backup.exclude = [ config.my.archAntigo.repo ]; }

    (lib.mkIf config.my.services.arch-antigo-mount {
      systemd.tmpfiles.rules = [
        "d ${config.my.archAntigo.local} 0755 v1cferr users -" # the owner is the user: they are the one who mounts
      ];
    })
  ];
}
