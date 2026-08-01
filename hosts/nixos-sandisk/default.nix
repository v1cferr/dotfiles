# Host: nixos-sandisk — MESMA máquina física (MOBO ASUS EX-B560M-V5), rodando do
# SSD SanDisk (SATA). É o ALVO ATIVO do cutover (Seagate → SanDisk). Só o
# específico; o comum vem de ../system. Disco DECLARATIVO via disko.
# PREPARAÇÃO — nada é formatado num rebuild normal; só no cutover (ver README).
{ modulesPath, ... }:

{
  imports = [
    ./disko.nix # disko gera os fileSystems da SanDisk
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  networking.hostName = "nixos-sandisk";

  # ═══ MAPA DE DISCOS (MOBO EX-B560M-V5) — montagens extras ════════════════════
  # A SanDisk (/ e /boot) vem do disko. Aqui fica o ACESSO aos outros discos.
  # Sempre por UUID (sdX/nvmeX embaralham entre boots). Todos com nofail (não falha
  # o boot se o disco sumir) + x-systemd.device-timeout=5s: SEM o timeout o systemd
  # espera 90s pelo device ausente e TRAVA o `nixos-rebuild switch` — o nofail sozinho
  # só evita a FALHA, não a ESPERA. Com 5s ele desiste rápido e o switch segue.

  # Seagate (HDD, ex-sistema) — ext4. Agora é o DESTINO do backup restic off-disk
  # (/mnt/seagate-old/restic); o sistema antigo da migração foi apagado. Ver system/restic.nix.
  fileSystems."/mnt/seagate-old" = {
    device = "/dev/disk/by-uuid/85788f24-b8a0-4c3e-af4f-8af1f8b52147";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.device-timeout=5s" ];
  };

  # Kingston (NVMe Gen4, Arch) — ext4, RW.
  fileSystems."/mnt/kingston-arch" = {
    device = "/dev/disk/by-uuid/d98ec566-6ec2-4371-8048-d3a4f02b2cbb";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.device-timeout=5s" ];
  };

  # Swapfile de disco (backstop de capacidade — o porquê está em system/hardware/
  # hardware.nix, junto do zram). Mora no host porque depende do FS da raiz: aqui é
  # ext4, então o NixOS cria e formata /swapfile na ativação, sem gambiarra de CoW.
  # No nixos-kingston (btrfs) quem faz isso é o disko, num subvolume NOCOW. Em MB.
  swapDevices = [
    { device = "/swapfile"; size = 16 * 1024; } # 16 GB (= RAM)
  ];

  # Kernel — MESMO hardware do Seagate (mesma MOBO/CPU). SanDisk é SATA (ahci +
  # sd_mod). No cutover, dá pra regenerar com nixos-generate-config se algo mudar.
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];

  # Fixado na 1ª instalação (no cutover) — NUNCA mudar depois.
  system.stateVersion = "26.05";
}
