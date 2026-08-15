# Hardware: CPU/firmware, GPU, audio, fonts.
{ ... }:

{
  imports = [
    ./hardware.nix # CPU/microcode, firmware, zram, Bluetooth, udisks2
    ./btrfs.nix # the FS' integrity: scrub plus alarm, error counters, reclaim, TRIM
    ./oom.nix # earlyoom: it kills the biggest process before the out-of-RAM freeze (zram's companion)
    ./gpu.nix # the video driver: an Intel Arc B580 (xe plus Mesa, no CUDA)
    ./audio.nix # PipeWire plus rtkit
    ./fonts.nix # the SSOT of the UI font (my.fonts.ui) plus fontconfig plus the MS metrics
    ./mouse.nix # a Logitech MX Master 3S through logiops (gestures, DPI, smartshift)
  ];
}
