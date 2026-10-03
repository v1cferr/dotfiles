# LOCAL SNAPSHOTS (btrbk): the minutes-scale "undo" for @home, NOT a backup (same disk, and no
# off-disk copy since 24/09/2026). @home only and /.snapshots: docs/notes/boot-and-storage/btrbk.md
{ config, lib, ... }:

lib.mkIf config.my.services.btrbk {
  # With /.snapshots unmounted, btrbk would write inside `@`, where
  # impermanence erases everything, and without the owner noticing.
  systemd.services.btrbk-home.unitConfig.RequiresMountsFor = "/.snapshots";

  # ROOT, with no sudo in between: the module's `btrbk` user calls sudo, and execWheelOnly (users.nix)
  # forbids a non-wheel caller from even executing it. Silently broken from 30/09 to 03/10/2026.
  systemd.services.btrbk-home.serviceConfig = {
    User = lib.mkForce "root";
    Group = lib.mkForce "root";
  };

  # The timer stays "active (waiting)" while every run fails, so the failure itself is the alarm:
  # without it the 30/09 breakage sat in the journal for 3 days. Pruning dies with it, too.
  systemd.services.btrbk-home.onFailure = [ "btrbk-alert-failed.service" ];

  systemd.services.btrbk-alert-failed = {
    description = "Alarm: a btrbk snapshot run failed";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''
        ${lib.getExe config.my.alert} btrbk drive-harddisk \
          "btrbk: the @home snapshot failed" \
          "See 'journalctl -u btrbk-home -n 30'. Until it is fixed there is no new snapshot, and old ones are not pruned."
      '';
    };
  };

  # (Persistent=true on the timer, which matters on this machine since it reboots a lot, already
  # comes from the btrbk module; there is no need to repeat it here.)

  services.btrbk.instances.home = {
    onCalendar = "hourly";
    settings = {
      backend = "btrfs-progs"; # not the module's btrfs-progs-sudo: it already runs as root
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
