# The ex-b560m-v5's hardware: its CPU, kernel modules, the disks beyond the root, monitors and
# devices. modules/ offers device modules; the host picks them: docs/notes/repo/flake.md
{ modulesPath, pkgs, ... }:

let
  # The Seagate Momentus 7200.4 (2009): its serial, the one fact both rules below key on.
  seagateSerial = "5VH4YZV8";
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../modules/nixos/hardware/intel-arc-b580.nix # the video driver: an Intel Arc B580 (xe plus Mesa, no CUDA)
    ../../modules/nixos/hardware/arc-b580-rgb.nix # the GPU's LEDs through a patched OpenRGB (my.rgb.color)
    ../../modules/nixos/hardware/mx-master-3s.nix # a Logitech MX Master 3S through logiops (gestures, DPI)
    ../../modules/nixos/hardware/deathadder-v2.nix # a Razer DeathAdder V2: hidraw for the user, no driver
  ];

  hardware.cpu.intel.updateMicrocode = true; # an Intel CPU on this board

  # MONITORS: the SSOT of the connector names, read by Nix, Lua and QML. Declared (with no
  # default, on purpose) in modules/nixos/desktop/monitors.nix.
  my.monitors = {
    primary = "DP-1"; # an ASUS ROG Strix XG27ACS, QHD (DisplayPort)
    secondary = "DP-2"; # an LG ULTRAGEAR, standing on its pivot (DisplayPort)
  };

  # EXTRA MOUNTS (the root and /boot come from disko). By UUID, since sdX/nvmeX shuffle.
  # nofail + device-timeout=5s: without it systemd waits 90s and freezes the switch.

  # The Seagate (an HDD): COLD STORAGE. It holds the frozen restic repos, the old Arch archive
  # that /mnt/arch-antigo reads included, since the daily backup was retired on 24/09/2026.
  # See docs/notes/boot-and-storage/restic.md
  fileSystems."/mnt/seagate-old" = {
    device = "/dev/disk/by-uuid/85788f24-b8a0-4c3e-af4f-8af1f8b52147";
    fsType = "ext4";
    options = [
      "nofail"
      "x-systemd.device-timeout=5s"
    ];
  };

  # The Seagate's WEAR, not its media (SMART on 03/10/2026: 0 reallocated, 850k load cycles). APM
  # 254 stops the head parking every few seconds; -S 241 spins it down after 30 idle minutes.
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="sd[a-z]", ENV{ID_SERIAL_SHORT}=="${seagateSerial}", RUN+="${pkgs.hdparm}/bin/hdparm -B 254 -S 241 /dev/%k"
  '';

  # smartd's defaults (modules/nixos/hardware/smartd.nix) plus what only this old disk needs: a
  # temperature alarm (spec max 43 C) and self-tests, short weekly and long monthly.
  services.smartd.devices = [
    {
      device = "/dev/disk/by-id/ata-ST9320423AS_${seagateSerial}";
      options = "-W 4,45,50 -s (S/../../7/04|L/../01/./05)";
    }
  ];

  # The SanDisk (Windows 11's C:). The full reasoning, the verification that preceded deleting the
  # local copies and the `force` option that must stay off: docs/notes/boot-and-storage/games-disk.md
  #
  # It used to be deliberately unmounted, and BOTH of the reasons
  # written here then have since been answered rather than ignored. It is mounted now because the
  # games live in `C:\\Games` and are meant to be ONE install played from either system, instead of
  # a copy on each disk (MEASURED on 31/08: 135 GiB of the Kingston was a duplicate of what was
  # already sitting here).
  #
  # "restic sweeping 900 GB" does not apply: the daily backup's `paths` was `/home/v1cferr` and
  # nothing else, so a mount under /mnt was never in its scope. That backup is gone since
  # 24/09/2026 anyway (docs/notes/boot-and-storage/restic.md), which settles it for good.
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

  # The btrfs POLICY (scrub, alarms, reclaim, TRIM) lives in modules/nixos/hardware/btrfs.nix: it is
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
}
