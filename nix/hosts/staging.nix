# Host de staging: primeiro roda como VM (build-vm), depois vira a instalação
# bare metal de teste no NVMe novo (aí entra disko + hardware-configuration).
{ config, pkgs, ... }:

{
  imports = [
    ../modules/base.nix
    ../modules/desktop.nix
  ];

  networking.hostName = "nixos-staging";

  # Placeholder para a config avaliar; a VM (vmVariant) sobrescreve isso com
  # disco virtual próprio, e no metal o disko/hardware-configuration substitui.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Senha inicial só para a fase VM — trocar/remover no metal.
  users.users.v1cferr.initialPassword = "nixos";

  # Ajustes que valem SÓ quando rodando como VM (build-vm)
  virtualisation.vmVariant = {
    virtualisation.memorySize = 6144; # MB
    virtualisation.cores = 4;
  };

  # NÃO mudar após a primeira instalação real (não é "versão do sistema")
  system.stateVersion = "25.11";
}
