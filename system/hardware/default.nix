# Hardware: CPU/firmware, GPU, áudio, fontes.
{ ... }:

{
  imports = [
    ./hardware.nix # CPU/microcode, firmware, zram, Bluetooth, udisks2
    ./btrfs.nix # integridade do FS: scrub + alarme, contadores de erro, reclaim, TRIM
    ./oom.nix # earlyoom: mata o maior processo antes do freeze por falta de RAM (companheiro do zram)
    ./gpu.nix # driver de vídeo: Intel Arc B580 (xe + Mesa, sem CUDA)
    ./audio.nix # PipeWire + rtkit
    ./fonts.nix # SSOT da fonte de UI (my.fonts.ui) + fontconfig + métricas MS
    ./mouse.nix # Logitech MX Master 3S via logiops (gestos → workspaces, DPI, smartshift)
  ];
}
