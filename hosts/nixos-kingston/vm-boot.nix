# The VM variant of this host: the WHOLE config, minus what needs the real hardware, a secret or
# another machine. What the boot test proves and what it cannot: docs/notes/repo/vm-boot.md
{
  lib,
  options,
  ...
}:

{
  # disko generates the Kingston's fileSystems, and the test VM brings its own root: keeping both
  # makes the boot wait forever for a device that does not exist (disko issue #668, same cause).
  disko.devices = lib.mkForce { };

  # The Seagate is a SECOND disk. tmpfs so the mount point exists and nothing waits for it.
  fileSystems."/mnt/seagate-old" = lib.mkForce {
    device = "none";
    fsType = "tmpfs";
  };

  # EVERY optional service off, read from the OPTION SET and not from a copy of the list, so a
  # toggle added tomorrow is off here by construction (rule 11).
  my.services = lib.genAttrs (builtins.attrNames options.my.services) (_: lib.mkForce false);

  # No GPU and no monitor: the compositor is not what this test is about, and a session that cannot
  # start would drown the failed-unit list it exists to read.
  services.xserver.displayManager.lightdm.enable = lib.mkForce false;
  services.displayManager.autoLogin.enable = lib.mkForce false;

  # The VM: 4 GiB because the closure is a desktop one, and the store comes from the host, so the
  # disk only holds what boots.
  virtualisation.memorySize = 4096;
  virtualisation.cores = 2;
}
