# HARDWARE: CPU/microcode, firmware, zram, Bluetooth and removable media. The SAME physical
# machine on every host (an ASUS EX-B560M-V5 board). The GPU (an Intel Arc B580) lives in
# system/gpu.nix.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true; # it includes the GPU's firmware (Intel Arc)
  zramSwap.enable = true; # compressed swap in RAM (fast; priority 5, so it is used first)

  # THE ON-DISK SWAPFILE lives in the HOST, not here: it depends on the root's filesystem. On
  # nixos-kingston's btrfs it needs a NOCOW subvolume, and what creates it is disko. Declaring it
  # here TOO would generate a second swapfile, on CoW, which the kernel refuses to activate. (On
  # an ext4 host it would be a plain /swapfile through swapDevices; that was the case of the
  # extinct nixos-sandisk.) The zram above is disk-agnostic and that is why it stays.
  #
  # The motivation (it holds for both hosts): zram compresses but it does NOT add space. When the
  # 16 GB plus zram get tight (Minecraft with an 8 GB heap plus VSCode plus a browser), the
  # overflow to disk keeps the OOM killer from killing apps. The default priority (negative) is
  # below zram's (5): a hot page goes to zram, and the disk only takes the cold overflow.

  # fwupd = firmware updates through LVFS (`fwupdmgr refresh && fwupdmgr update`).
  # It does NOT cover this board's BIOS (the ASUS EX-B560M-V5 is not in LVFS, so use EZ Flash 3 in
  # the UEFI with a FAT32 stick). It serves the NVMe SSD and other components.
  services.fwupd.enable = true;

  # ── Bluetooth ───────────────────────────────────────────────────────────────
  # BlueZ (the stack) plus turning the adapter on at boot. blueman is the tray applet/GUI for
  # pairing/managing on a desktop with no DE (Hyprland). BT audio goes out through PipeWire.
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true; # the adapter turns on at boot (always ready)
  # Experimental: it turns on the headset's BATTERY reporting (%) plus extra BlueZ features.
  hardware.bluetooth.settings.General.Experimental = true;
  services.blueman.enable = true;

  # ── Removable media (a USB stick, an external HD) ───────────────────────────
  # udisks2 is the backend Dolphin/Solid uses to MOUNT removable media on a click. Without it, USB
  # does not mount. (The installer's live USB is NOT declared; it is transient.)
  services.udisks2.enable = true;
}
