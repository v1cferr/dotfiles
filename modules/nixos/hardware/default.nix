# Hardware ANY host can carry: firmware, btrfs, OOM, audio, fonts, Bluetooth, adb. A device
# module (one GPU, one mouse) is not imported here: each host's hardware.nix picks its own.
{ ... }:

{
  imports = [
    ./hardware.nix # firmware, zram, fwupd, Bluetooth, udisks2 (the microcode is the host's CPU)
    ./btrfs.nix # the FS' integrity: scrub plus alarm, error counters, reclaim, TRIM
    ./oom.nix # earlyoom: it kills the biggest process before the out-of-RAM freeze (zram's companion)
    ./audio.nix # PipeWire plus rtkit
    ./fonts.nix # the SSOT of the UI font (my.fonts.ui) plus fontconfig plus the MS metrics
    ./android.nix # adb over wireless debugging, scrcpy and uad-ng, to inspect and clean the phone
  ];
}
