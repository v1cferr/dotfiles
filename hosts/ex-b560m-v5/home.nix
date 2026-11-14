# The part of my home that only THIS desk has: its two DDC panels, its mouse, the autologin keyring
# and lock, the mounts its VPN reaches and its weekly drill: docs/decisions/0018-a-shared-laptop.md
{ ... }:

{
  home-manager.users.v1cferr = {
    imports = [
      ../../modules/home/desktop/backlight.nix # DDC/CI: both panels held at one declared brightness and white point
      ../../modules/home/desktop/keyring.nix # the "Login" keyring unlocked at start from a TPM-sealed password (autologin)
      ../../modules/home/desktop/lockscreen # the session lock plus hypridle: this desk logs in by itself, so the lock IS its login
      ../../modules/home/services/fai-workstation-mount.nix # ~/FAI-workstation = SFTP to the FAI workstation (rclone plus cache), under the VPN
      ../../modules/home/services/razer-dpi.nix # the OSD for the Razer mouse's onboard DPI button (it polls hidraw)
      ../../modules/home/services/vm-boot-drill.nix # the weekly drill: it rebuilds the VM boot test and only speaks on failure
    ];
  };
}
