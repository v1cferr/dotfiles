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

  # Kernel — MESMO hardware do Seagate (mesma MOBO/CPU). SanDisk é SATA (ahci +
  # sd_mod). No cutover, dá pra regenerar com nixos-generate-config se algo mudar.
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];

  # Fixado na 1ª instalação (no cutover) — NUNCA mudar depois.
  system.stateVersion = "26.05";
}
