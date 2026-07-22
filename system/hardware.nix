# ═══════════════════════════════════════════════════════════════════════════
# HARDWARE — CPU/microcode, firmware, zram, GPU NVIDIA, Bluetooth e mídia
# removível. MESMA máquina física em todos os hosts (MOBO ASUS EX-B560M-V5).
# ═══════════════════════════════════════════════════════════════════════════
{ config, ... }:

{
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  zramSwap.enable = true; # swap comprimido na RAM

  # ── GPU: NVIDIA RTX 3050 (Ampere) — driver proprietário ──────────────────────
  # nouveau em Ampere não faz reclocking (fica lento) e não tem CUDA. O driver
  # proprietário com módulos ABERTOS é o caminho recomendado p/ Turing+ e o que
  # faz Hyprland/Wayland + Vulkan + CUDA funcionarem de verdade.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true; # OpenGL/Vulkan (ex-hardware.opengl)
  hardware.graphics.enable32Bit = true; # libs 32-bit p/ Wine/Proton (Bottles/WoW)
  hardware.nvidia = {
    modesetting.enable = true; # obrigatório p/ Wayland/Hyprland
    open = true; # módulos abertos (Ampere suporta; recomendado)
    nvidiaSettings = true; # app gráfico nvidia-settings
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # ── Bluetooth ───────────────────────────────────────────────────────────────
  # BlueZ (stack) + liga o adaptador no boot. blueman = applet/GUI de bandeja
  # pra parear/gerenciar em desktop sem DE (Hyprland). Áudio BT sai via PipeWire.
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true; # adaptador liga no boot (sempre pronto)
  # Experimental: liga o relato de BATERIA do fone (%) + features extras do BlueZ.
  hardware.bluetooth.settings.General.Experimental = true;
  services.blueman.enable = true;

  # ── Mídia removível (pendrive, HD externo) ──────────────────────────────────
  # udisks2 = backend que o Dolphin/Solid usa pra MONTAR removível no clique. Sem
  # isso, USB não monta. (O live USB do instalador NÃO se declara — é transitório.)
  services.udisks2.enable = true;
}
