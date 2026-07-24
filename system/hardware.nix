# ═══════════════════════════════════════════════════════════════════════════
# HARDWARE — CPU/microcode, firmware, zram, Bluetooth e mídia removível. MESMA
# máquina física em todos os hosts (MOBO ASUS EX-B560M-V5). A GPU (NVIDIA/Intel,
# trocável no boot) mora em system/gpu.nix.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true; # inclui firmware da GPU (Intel Arc/NVIDIA)
  zramSwap.enable = true; # swap comprimido na RAM

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
