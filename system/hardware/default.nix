# Hardware: CPU/firmware, GPU, áudio, fontes.
{ ... }:

{
  imports = [
    ./hardware.nix # CPU/microcode, firmware, zram, Bluetooth, udisks2
    ./oom.nix # earlyoom: mata o maior processo antes do freeze por falta de RAM (companheiro do zram)
    ./gpu.nix # driver de vídeo: Intel Arc B580 (xe + Mesa, sem CUDA)
    ./audio.nix # PipeWire + rtkit
    ./fonts.nix # JetBrainsMono Nerd Font (padrão mono/sans/serif)
  ];
}
