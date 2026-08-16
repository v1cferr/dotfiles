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

  # The SanDisk (Windows 11) is NOT mounted on purpose: os-prober only needs its ESP, and
  # mounting C: invites NTFS writes with fast-startup pending plus restic sweeping 900 GB.

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
