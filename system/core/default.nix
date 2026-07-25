# Núcleo do sistema: Nix/flakes, boot, usuários, segredos, locale.
{ ... }:

{
  imports = [
    ./core.nix # Nix/flakes, nixpkgs (unfree/inseguros), nix-ld, locale/idioma
    ./boot.nix # bootloader UEFI (systemd-boot). GRUB+minegrub em boot-grub.nix (swap manual EM CASA)
    ./users.nix # zsh como shell de login + a conta v1cferr
    ./secrets.nix # base do sops + sops.secrets do Bitwarden + comando sync-secrets
    # ./boot-grub.nix — DORMENTE (alternativa GRUB): trocar por ./boot.nix acima só EM CASA
  ];
}
