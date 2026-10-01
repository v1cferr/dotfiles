# The BOOT test's variant: the whole config on the test framework's own root, so it never touches a
# disk layout. What it proves and what it cannot: docs/notes/repo/vm-boot.md
{ lib, ... }:

{
  imports = [ ./vm-common.nix ];

  # disko generates the Kingston's fileSystems, and the test VM brings its own root: keeping both
  # makes the boot wait forever for a device that does not exist (disko issue #668, same cause).
  disko.devices = lib.mkForce { };

  # 4 GiB because the closure is a desktop one; the store comes from the host, so no disk is needed.
  virtualisation.memorySize = 4096;
  virtualisation.cores = 2;
}
