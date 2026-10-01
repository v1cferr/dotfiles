# Hardware ANY host can carry: firmware, btrfs, OOM, audio, Bluetooth, adb. A device
# module (one GPU, one mouse) is not imported here: each host's hardware.nix picks its own.
{ ... }:

{
  imports = [
    ./hardware.nix # firmware, zram, fwupd, Bluetooth, udisks2 (the microcode is the host's CPU)
    ./btrfs.nix # the FS' integrity: scrub plus alarm, error counters, reclaim, TRIM
    ./oom.nix # earlyoom: it kills the biggest process before the out-of-RAM freeze (zram's companion)
    ./audio.nix # PipeWire plus rtkit
    ./android.nix # adb over wireless debugging, scrcpy and uad-ng, to inspect and clean the phone
  ];
}
