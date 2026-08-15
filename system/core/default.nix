# The system's core: Nix/flakes, boot, users, secrets, locale.
{ ... }:

{
  imports = [
    ./core.nix # Nix/flakes, nixpkgs (unfree/insecure), nix-ld, locale/language
    ./boot.nix # GRUB (UEFI) plus the minegrub theme plus Windows 11 in the menu through os-prober
    ./secureboot.nix # Secure Boot: our own keys (sbctl) and signing GRUB on every switch
    ./shutdown.nix # the ceiling on systemd's wait when stopping a unit (the end of the 90 s "stop job")
    ./users.nix # zsh as the login shell plus the v1cferr account
    ./secrets.nix # the sops base plus the sops.secrets from Bitwarden plus the sync-secrets command
  ];
}
