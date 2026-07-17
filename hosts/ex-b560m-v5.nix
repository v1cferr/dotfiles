# Host: ex-b560m-v5 — MESMA máquina física (MOBO ASUS EX-B560M-V5), mas rodando
# do SSD Kingston (destino do cutover). Só o específico; o comum vem de ../system.
# O disco é DECLARATIVO via disko. PREPARAÇÃO — ainda NÃO instalado; nada é
# aplicado/formatado agora. No cutover: disko formata o Kingston + nixos-install.
{ modulesPath, ... }:

{
  imports = [
    ./ex-b560m-v5-disko.nix # disko gera os fileSystems do Kingston
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  networking.hostName = "ex-b560m-v5";

  # Kernel — MESMO hardware do Seagate (mesma MOBO/CPU), então valem aqui também.
  # No cutover, dá pra regenerar com nixos-generate-config se algo mudar.
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];

  # Fixado na 1ª instalação (no cutover) — NUNCA mudar depois.
  system.stateVersion = "26.05";
}
