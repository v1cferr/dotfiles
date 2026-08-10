# Núcleo do sistema: Nix/flakes, boot, usuários, segredos, locale.
{ ... }:

{
  imports = [
    ./core.nix # Nix/flakes, nixpkgs (unfree/inseguros), nix-ld, locale/idioma
    ./boot.nix # GRUB (UEFI) + tema minegrub + Windows 11 no menu via os-prober
    ./secureboot.nix # Secure Boot: chaves próprias (sbctl) e assinatura do GRUB no switch
    ./shutdown.nix # teto de espera do systemd ao parar unit (fim do "stop job" de 90 s)
    ./users.nix # zsh como shell de login + a conta v1cferr
    ./secrets.nix # base do sops + sops.secrets do Bitwarden + comando sync-secrets
  ];
}
