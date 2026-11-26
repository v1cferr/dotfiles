# The part of my home that only THIS desk has: its two DDC panels, its mouse, the autologin keyring
# and lock, its games, the mounts its VPN reaches and its weekly drill: docs/decisions/0018-a-shared-laptop.md
{ ... }:

{
  home-manager.users.v1cferr = {
    imports = [
      ./games.nix # the games on its Windows disk, their saves and their Bottles entries, beyond WoW
      ../../modules/home/desktop/backlight.nix # DDC/CI: both panels held at one declared brightness and white point
      ../../modules/home/desktop/keyring.nix # the TPM-sealed password oo7 unlocks the "Login" keyring with (autologin)
      ../../modules/home/desktop/lockscreen # the session lock plus hypridle: this desk logs in by itself, so the lock IS its login
      ../../modules/home/services/fai-workstation-mount.nix # ~/FAI-workstation = SFTP to the FAI workstation (rclone plus cache), under the VPN
      ../../modules/home/services/razer-dpi.nix # the OSD for the Razer mouse's onboard DPI button (it polls hidraw)
      ../../modules/home/services/vm-boot-drill.nix # the weekly drill: it rebuilds the VM boot test and only speaks on failure
    ];
  };
}
