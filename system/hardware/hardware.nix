# BlueZ plus blueman (the tray applet, since Hyprland has no DE). BT audio goes through PipeWire.
{ ... }:

{
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true; # it includes the GPU's firmware (Intel Arc)
  zramSwap.enable = true; # compressed swap in RAM (fast; priority 5, so it is used first)

  # THE ON-DISK SWAPFILE lives in the HOST, since it depends on the root's filesystem (btrfs needs
  # a NOCOW subvolume, made by disko). zram is disk-agnostic, which is why it stays here.

  # fwupd: firmware through LVFS. It does NOT cover this board's BIOS (use EZ Flash 3 in the UEFI).
  services.fwupd.enable = true;

  # ── Bluetooth ───────────────────────────────────────────────────────────────
  # BlueZ (the stack) plus turning the adapter on at boot. blueman is the tray applet/GUI for
  # pairing/managing on a desktop with no DE (Hyprland). BT audio goes out through PipeWire.
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true; # the adapter turns on at boot (always ready)
  # Experimental: the headset's BATTERY reporting (%) plus extra BlueZ features.
  hardware.bluetooth.settings.General.Experimental = true;
  services.blueman.enable = true;

  # udisks2: the backend Dolphin/Solid uses to MOUNT removable media on a click.
  services.udisks2.enable = true;
}
