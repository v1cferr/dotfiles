# DISK HEALTH (smartd): every disk watched, and only a real decline reaches me, through my.alert.
# What fires, what does not and why no NVMe temperature alarm: docs/notes/hardware/smart.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs) writeShellApplication;

  # smartd hands the details over in the environment; `-M exec` cannot take arguments.
  notify = writeShellApplication {
    name = "smartd-alert";
    text = ''
      exec ${lib.getExe config.my.alert} smartd drive-harddisk \
        "smartd: ''${SMARTD_DEVICESTRING:-a disk}" "''${SMARTD_MESSAGE:-no message}"
    '';
  };

  # -a: health, failed attributes, new log errors, pending and offline sectors. standby,q: never
  # spin a sleeping disk up just to look at it.
  watch = "-a -n standby,q -M exec ${lib.getExe notify}";
in
{
  services.smartd = {
    enable = true;
    # The module's own channels: no mailer here, and wall and xmessage reach nobody on Wayland.
    notifications = {
      mail.enable = false;
      wall.enable = false;
      x11.enable = false;
      # Agreeing with earlyoom, whose mkDefault clashes with ours. Inert: with the three above off
      # the module never calls its own script, so this sends nothing.
      systembus-notify.enable = config.services.earlyoom.enable;
    };
    defaults = {
      monitored = watch;
      autodetected = watch;
    };
  };
}
