# Host nixos-kingston: ASUS EX-B560M-V5, daily driver, running off the Kingston KC3000.
# Only what is specific to this machine; the shared config is ../../system.
{ modulesPath, ... }:

{
  imports = [
    ./disko.nix # disko generates the Kingston's fileSystems (btrfs plus subvolumes)
    ./services.nix # THE PANEL: which optional services this machine turns on (my.services.*)
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  networking.hostName = "nixos-kingston";

  # MONITORS: the SSOT of the connector names, read by Nix, Lua and QML. Declared (with no
  # default, on purpose) in system/desktop/monitors.nix.
  my.monitors = {
    primary = "DP-2"; # an LG ULTRAGEAR (DisplayPort)
    secondary = "HDMI-A-3"; # an LG TV (HDMI)
  };

  # EXTRA MOUNTS (the root and /boot come from disko). By UUID, since sdX/nvmeX shuffle.
  # nofail + device-timeout=5s: without it systemd waits 90s and freezes the switch.

  # The Seagate (an HDD): the destination of the off-disk restic backup. See
  # system/services/restic.nix.
  fileSystems."/mnt/seagate-old" = {
    device = "/dev/disk/by-uuid/85788f24-b8a0-4c3e-af4f-8af1f8b52147";
    fsType = "ext4";
    options = [
      "nofail"
      "x-systemd.device-timeout=5s"
    ];
  };

  # The SanDisk (Windows 11's C:). The full reasoning, the verification that preceded deleting the
  # local copies and the `force` option that must stay off: docs/notes/boot-and-storage/games-disk.md
  #
  # It used to be deliberately unmounted, and BOTH of the reasons
  # written here then have since been answered rather than ignored. It is mounted now because the
  # games live in `C:\\Games` and are meant to be ONE install played from either system, instead of
  # a copy on each disk (MEASURED on 31/08: 135 GiB of the Kingston was a duplicate of what was
  # already sitting here).
  #
  # "restic sweeping 900 GB" does not apply: restic's `paths` is `/home/v1cferr` and nothing else,
  # so a mount under /mnt was never in its scope (`system/services/restic.nix`).
  #
  # "NTFS writes with fast-startup pending" is real and is handled by what is ABSENT here: the
  # ntfs3 `force` option. Without it the driver REFUSES a read-write mount of a dirty volume, so a
  # Windows hybrid shutdown makes this mount FAIL, which `nofail` turns into a boot that carries on
  # and a game that will not start. That is the correct failure: loud, and never a half-written
  # NTFS. Never add `force` to make an error go away; run `powercfg /h off` on the Windows side.
  #
  # `windows_names` for the same reason the disk is shared at all: it refuses to create a name
  # Windows could not open, so Linux cannot leave a file there that only Linux can see.
  fileSystems."/mnt/windows" = {
    device = "/dev/disk/by-uuid/26486763486730AB";
    fsType = "ntfs3";
    options = [
      "uid=1000" # v1cferr: NTFS has no unix owner, so the mount assigns one
      "gid=100" # users
      "iocharset=utf8"
      "windows_names"
      "noatime" # an atime write per file read, on a disk holding nothing but games
      "nofail"
      "x-systemd.device-timeout=5s"
    ];
  };

  # The btrfs POLICY (scrub, alarms, reclaim, TRIM) lives in system/hardware/btrfs.nix: it is
  # guarded by "is the root btrfs?", not by the host. Only the LAYOUT is host-specific.

  # The kernel: the SAME hardware as the SanDisk's (the same board/CPU); only the root became an
  # NVMe.
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  # Fixed at the 1st install: NEVER change it afterwards. The same value as the old host because
  # it is the same release; the stateVersion follows the installation, not the disk.
  system.stateVersion = "26.05";
}
