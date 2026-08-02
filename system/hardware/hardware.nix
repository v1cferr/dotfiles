# ═══════════════════════════════════════════════════════════════════════════
# HARDWARE — CPU/microcode, firmware, zram, Bluetooth e mídia removível. MESMA
# máquina física em todos os hosts (MOBO ASUS EX-B560M-V5). A GPU (Intel Arc
# B580) mora em system/gpu.nix.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true; # inclui firmware da GPU (Intel Arc)
  zramSwap.enable = true; # swap comprimido na RAM (rápido; prio 5 → usado primeiro)

  # O SWAPFILE DE DISCO mora no HOST, não aqui: ele depende do filesystem da raiz.
  # No btrfs do nixos-kingston ele precisa de subvolume NOCOW, e quem o cria é o
  # disko. Declarar aqui TAMBÉM geraria um segundo swapfile — em CoW, que o kernel
  # recusa ativar. (Num host ext4 seria um /swapfile comum via swapDevices; foi o
  # caso do extinto nixos-sandisk.) O zram acima é agnóstico de disco e por isso fica.
  #
  # Motivação (vale pros dois hosts): o zram comprime mas NÃO adiciona espaço. Quando
  # os 16 GB + zram apertam (Minecraft com 8 GB de heap + VSCode + navegador), o
  # overflow em disco evita o OOM killer matar apps. Prioridade default (negativa) <
  # zram (5): página quente vai pro zram, o disco só pega o overflow frio.

  # fwupd = updates de firmware via LVFS (`fwupdmgr refresh && fwupdmgr update`).
  # NÃO cobre a BIOS desta placa (ASUS EX-B560M-V5 não está no LVFS → usar EZ Flash
  # 3 na UEFI c/ pendrive FAT32). Serve p/ SSD NVMe e outros componentes.
  services.fwupd.enable = true;

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
