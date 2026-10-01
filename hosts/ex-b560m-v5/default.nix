# Host ex-b560m-v5: an ASUS EX-B560M-V5 board, the daily driver, running off the Kingston KC3000.
# Identity and composition; the shared config is ../../modules/nixos, the hardware ./hardware.nix.
{ ... }:

{
  imports = [
    ./disko.nix # disko generates the Kingston's fileSystems (btrfs plus subvolumes)
    ./services.nix # THE PANEL: which optional services this machine turns on (my.services.*)
    ./hardware.nix # THIS machine's hardware: kernel modules, microcode, extra disks, monitors, devices
  ];

  networking.hostName = "ex-b560m-v5";

  # The router this machine manages (router-sync, `ssh router`): its facts live in its own folder.
  my.router = import ../cudy-wr3000;

  # Fixed at the 1st install: NEVER change it afterwards. The same value as the old host because
  # it is the same release; the stateVersion follows the installation, not the disk.
  system.stateVersion = "26.05";
}
