# Host: nixos-kingston, an ASUS EX-B560M-V5 board, running from the Kingston KC3000 NVMe.
# It is the DAILY DRIVER (the cutover happened on 01/08/2026): the fastest disk got the everyday
# system, and the SanDisk (SATA) became the dualboot's Windows 11.
# Only the specific bits here; the common ones come from ../system. The disk is DECLARATIVE
# through disko (btrfs). Nothing is formatted on a normal rebuild, only on an explicit `disko`
# (see disko.nix).
{ modulesPath, ... }:

{
  imports = [
    ./disko.nix # disko generates the Kingston's fileSystems (btrfs plus subvolumes)
    ./services.nix # THE PANEL: which optional services this machine turns on (my.services.*)
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  networking.hostName = "nixos-kingston";

  # ═══ MONITORS: THIS board/GPU's connectors ════════════════════════════════
  # The SSOT of the names; the option is declared in system/desktop/monitors.nix (with no default,
  # on purpose) and read by Nix, Lua and QML. Changing a cable or a monitor = changing it HERE.
  my.monitors = {
    primary = "DP-2"; # an LG ULTRAGEAR (DisplayPort)
    secondary = "HDMI-A-3"; # an LG TV (HDMI)
  };

  # ═══ THE DISK MAP (the EX-B560M-V5 board): extra mounts ══════════════════════
  # The root and /boot come from disko. Here is the ACCESS to the other disks.
  # Always by UUID (sdX/nvmeX shuffle between boots). All with nofail (the boot does not fail if
  # the disk disappears) plus x-systemd.device-timeout=5s: WITHOUT the timeout systemd waits 90s
  # for the missing device and FREEZES the `nixos-rebuild switch`.

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

  # The SanDisk is NOT mounted on purpose. It became Windows 11 (NTFS), and the only partition
  # NixOS needs from it is the ESP, which os-prober mounts on its own, at switch time, to put
  # Windows in the GRUB menu (see system/core/boot.nix). Mounting the C: here would invite the two
  # things that ruin a dualboot: writing to NTFS with hibernation/fast startup pending, and restic
  # sweeping 900 GB that are not ours.

  # The monthly scrub and the rest of the btrfs POLICY (the alarm, the error counters, reclaim,
  # TRIM, nocow) left here for system/hardware/btrfs.nix: nothing there is specific to THIS
  # machine, since the guard is "is the root btrfs?", not "is it the Kingston?".
  # Here only the LAYOUT is left, which really is the host's (disko.nix).

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
