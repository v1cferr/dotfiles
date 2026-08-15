# ═══════════════════════════════════════════════════════════════════════════
# THE OLD ARCH ARCHIVE, the SYSTEM side: the mountpoint and the path's SSOT.
#
# What MOUNTS it is the user (home/services/arch-legacy-mount.nix): a FUSE mount is private to
# whoever mounted it, so `sudo restic mount` produces a folder Dolphin does not open. Root only
# comes in here to CREATE the directory, because /mnt is its and the user cannot write there.
#
# The option is born on this side and not in the home module because of rule 11: the tmpfiles
# below is a SYSTEM module and consumes the path, and a system module does not read a
# home-manager option. The home consumers (the unit and the Dolphin bookmark) read it through
# `osConfig.my.archAntigo.*`.
#
# The directory used to be created inside restic.nix until 11/08/2026, alongside /mnt/backup. It
# left because there it was tied to the `restic` toggle: turning the backup off would start taking
# down a mount that is now PERMANENT, and the failure would show up far from the cause (a mount
# with no mountpoint). /mnt/backup stays there because it remains an on-demand lookup by
# `backup-browse`, which is restic's domain.
#
# The repo is STATIC: nothing has written to it since 01/08/2026, when the Kingston was formatted
# (see docs/arch-legacy.md). That is not trivia, it is the premise that authorizes the `--no-lock`
# on the home side.
# ═══════════════════════════════════════════════════════════════════════════
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

  # OUTSIDE /home on purpose: a mountpoint inside /home/v1cferr would enter the backup's `paths`
  # and fall into the ~/Drive and ~/FAI-workstation trap, since root cannot lstat the user's FUSE,
  # restic exits 3 and the `forget --prune` stops running (the damage is documented in
  # system/services/restic.nix). In /mnt the problem does not even exist.
  config = lib.mkIf config.my.services.arch-antigo-mount {
    systemd.tmpfiles.rules = [
      "d ${config.my.archAntigo.local} 0755 v1cferr users -" # the owner is the user: they are the one who mounts
    ];
  };
}
