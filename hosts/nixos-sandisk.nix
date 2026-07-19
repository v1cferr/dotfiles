# Host: nixos-sandisk — MESMA máquina física (MOBO ASUS EX-B560M-V5), rodando do
# SSD SanDisk (SATA). É o ALVO ATIVO do cutover (Seagate → SanDisk). Só o
# específico; o comum vem de ../system. Disco DECLARATIVO via disko.
# PREPARAÇÃO — nada é formatado num rebuild normal; só no cutover (ver README).
{ modulesPath, ... }:

{
  imports = [
    ./nixos-sandisk-disko.nix # disko gera os fileSystems da SanDisk
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  networking.hostName = "nixos-sandisk";

  # ═══ MAPA DE DISCOS (MOBO EX-B560M-V5) — montagens extras ════════════════════
  # A SanDisk (/ e /boot) vem do disko. Aqui fica o ACESSO aos outros discos.
  # Sempre por UUID (sdX/nvmeX embaralham entre boots). Todos com nofail +
  # x-systemd.automount: montam no 1º acesso e NUNCA travam o boot se o disco sumir.

  # Seagate (HDD, ex-sistema) — ext4. CONTÉM o backup restic em /var/backup/restic:
  # é sua rede de segurança da migração; não apague esse dir até confiar no SSD.
  fileSystems."/mnt/seagate-old" = {
    device = "/dev/disk/by-uuid/85788f24-b8a0-4c3e-af4f-8af1f8b52147";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.automount" ];
  };

  # Kingston (NVMe Gen4, Arch) — ext4, RW.
  fileSystems."/mnt/kingston-arch" = {
    device = "/dev/disk/by-uuid/d98ec566-6ec2-4371-8048-d3a4f02b2cbb";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.automount" ];
  };

  # Netac (NVMe Gen3) — Windows/dados (NE-1TB 2280), NTFS somente leitura.
  fileSystems."/mnt/netac-win" = {
    device = "/dev/disk/by-uuid/CA9C7EDD9C7EC38B";
    fsType = "ntfs3";
    options = [ "ro" "nofail" "x-systemd.automount" "uid=1000" "gid=100" ];
  };

  # Kernel — MESMO hardware do Seagate (mesma MOBO/CPU). SanDisk é SATA (ahci +
  # sd_mod). No cutover, dá pra regenerar com nixos-generate-config se algo mudar.
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];

  # Fixado na 1ª instalação (no cutover) — NUNCA mudar depois.
  system.stateVersion = "26.05";
}
