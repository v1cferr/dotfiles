# The system's core: Nix/flakes, boot, users, secrets, locale.
{ ... }:

{
  imports = [
    ./core.nix # Nix/flakes, nixpkgs (unfree/insecure), nix-ld, locale/language
    ./boot.nix # the kernel, plus GRUB (UEFI) with the minegrub theme and Windows 11 pinned by UUID
    ./boot-appearance.nix # the pre-boot palette (my.boot.theme) and the Plymouth splash (off by default)
    ./secureboot.nix # Secure Boot: our own keys (sbctl) and signing GRUB on every switch
    ./alert.nix # `my.alert`: the journal plus a critical bubble, for root units that must reach me
    ./hardening.nix # the systemd sandbox baseline for this repo's own root oneshots
    ./shutdown.nix # the ceiling on systemd's wait when stopping a unit (the end of the 90 s "stop job")
    ./users.nix # zsh as the login shell plus the v1cferr account
    ./secrets.nix # the sops base plus the sops.secrets from Bitwarden plus the sync-secrets command
  ];
}
