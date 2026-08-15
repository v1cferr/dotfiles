# ═══════════════════════════════════════════════════════════════════════════
# LOCAL SNAPSHOTS (btrbk): the minutes-scale "undo" for @home.
#
# IT IS NOT A BACKUP, and the distinction matters: a snapshot lives on the SAME disk as the data.
# The Kingston died, so the snapshots died with it. What covers that is restic (restic.nix),
# off-disk on the Seagate plus the Drive. Both exist because they answer different questions:
#   • restic -> "the disk died / the house burned down"   (daily, off-disk, encrypted)
#   • btrbk  -> "I overwrote the file 20 minutes ago"     (hourly, instant, local)
# restic alone leaves a hole of up to 24 h and a restore that takes minutes; btrbk closes that
# hole for ~zero cost, because a CoW snapshot copies nothing: it only starts taking space to the
# EXTENT that the original data diverges.
#
# @home ONLY. The root is left out on purpose: on NixOS the system's rollback already is the GRUB
# generation list, and a snapshot of `/` would not even take /nix (a separate subvolume, since a
# snapshot does not descend into a nested subvolume). It would be noise with no gain.
#
# THE PREREQUISITE: the @snapshots subvolume mounted at /.snapshots (see disko.nix). On an already
# installed system it is created by hand ONCE; the command is over there.
#
# Restoring a file is a `cp` from /.snapshots/home.<timestamp>/…, since a snapshot is just a
# browsable directory. Reverting the WHOLE @home is a manual, conscious operation (swapping the
# subvolume), never automatic.
# ═══════════════════════════════════════════════════════════════════════════
{ config, lib, ... }:

lib.mkIf config.my.services.btrbk {
  # The same lock as restic (restic.nix): without /.snapshots mounted, btrbk would write inside
  # `@`, the one place where impermanence erases everything, and without the owner noticing.
  # RequiresMountsFor blocks that.
  systemd.services.btrbk-home.unitConfig.RequiresMountsFor = "/.snapshots";

  # (Persistent=true on the timer, which matters on this machine since it reboots a lot, already
  # comes from the btrbk module; there is no need to repeat it here.)

  services.btrbk.instances.home = {
    onCalendar = "hourly";
    settings = {
      timestamp_format = "long"; # it includes hour:minute, which an hourly snapshot needs

      # "onchange": nothing written since the last snapshot means it does not create a new one.
      # Without this, the machine on and idle would generate 24 identical snapshots a day and push
      # the useful ones out of the retention window.
      snapshot_create = "onchange";

      # 48h/7d/4w is about 2 days of fine granularity plus a month of safety net. It matches
      # restic (--keep-daily 7 --keep-weekly 4): btrbk covers what is too short for the daily
      # backup to reach.
      snapshot_preserve = "48h 7d 4w";
      snapshot_preserve_min = "latest"; # it never ends up with NO snapshot at all

      # The ABSOLUTE PATH form (with no `volume` section). btrbk's other form, `volume <pool>`
      # plus a relative subvolume, presumes subvolid=5 mounted in a directory, and mounting the
      # top permanently would make every subvolume appear TWICE in the tree (it confuses du/find
      # and any sweep). With an absolute path btrbk resolves /home directly, which is what we
      # want.
      snapshot_dir = "/.snapshots";
      subvolume."/home" = { }; # /home = the @home subvolume
    };
  };
}
