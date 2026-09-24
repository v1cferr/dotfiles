# LOCAL SNAPSHOTS (btrbk): the minutes-scale "undo" for @home. It is NOT a backup and never
# became one: a snapshot shares the disk it protects. The off-disk half was restic, retired on
# 24/09/2026, so today this is the ONLY automatic copy (docs/notes/boot-and-storage/restic.md).
# Why @home only, and the /.snapshots prerequisite: docs/notes/boot-and-storage/btrbk.md
{ config, lib, ... }:

lib.mkIf config.my.services.btrbk {
  # With /.snapshots unmounted, btrbk would write inside `@`, where
  # impermanence erases everything, and without the owner noticing.
  systemd.services.btrbk-home.unitConfig.RequiresMountsFor = "/.snapshots";

  # (Persistent=true on the timer, which matters on this machine since it reboots a lot, already
  # comes from the btrbk module; there is no need to repeat it here.)

  services.btrbk.instances.home = {
    onCalendar = "hourly";
    settings = {
      timestamp_format = "long"; # it includes hour:minute, which an hourly snapshot needs

      # "onchange": idle would otherwise mint 24 identical snapshots a day and evict the useful ones.
      snapshot_create = "onchange";

      # 48h/7d/4w: sized to start where restic's --keep-daily 7 was too coarse to reach.
      snapshot_preserve = "48h 7d 4w";
      snapshot_preserve_min = "latest"; # it never ends up with NO snapshot at all

      # The ABSOLUTE PATH form: btrbk's `volume <pool>` form needs subvolid=5 mounted, which would
      # make every subvolume show up TWICE in the tree. See the notes.
      snapshot_dir = "/.snapshots";
      subvolume."/home" = { }; # /home = the @home subvolume
    };
  };
}
