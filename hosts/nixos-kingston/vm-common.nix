# What EVERY VM of this host turns off: the hardware it does not have and the services that need a
# secret, a disk or another machine. The two entrypoints: docs/notes/repo/vm-boot.md
{
  lib,
  options,
  ...
}:

{
  # The Seagate is a SECOND physical disk. tmpfs so the mount point exists and nothing waits.
  fileSystems."/mnt/seagate-old" = lib.mkForce {
    device = "none";
    fsType = "tmpfs";
  };

  # EVERY optional service off, read from the OPTION SET and not from a copy of the list, so a
  # toggle added tomorrow is off here by construction (rule 11).
  my.services = lib.genAttrs (builtins.attrNames options.my.services) (_: lib.mkForce false);

  # No GPU and no monitor: the compositor is not what these VMs are about, and a session that
  # cannot start would drown the failed-unit list they exist to read.
  services.xserver.displayManager.lightdm.enable = lib.mkForce false;
  services.displayManager.autoLogin.enable = lib.mkForce false;
}
