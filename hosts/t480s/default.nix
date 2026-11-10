# Host t480s: a Lenovo ThinkPad T480s, the laptop two people share, each with their own home.
# One system here, two homes elsewhere: docs/decisions/0018-a-shared-laptop.md
{ ... }:

{
  imports = [
    ./disko.nix # disko generates the KIOXIA's fileSystems (LUKS, then btrfs plus subvolumes)
    ./hardware.nix # THIS machine's hardware: the model profile, kernel modules, the panel
    ./users.nix # the second account (cesar) and where both password hashes come from
    ./desktop.nix # GDM as the greeter and GNOME beside the shared Hyprland
  ];

  networking.hostName = "t480s";

  # The house's router, so `ssh router` works from here too; this machine does not manage it.
  my.router = import ../cudy-wr3000;

  # SSH for administration, by key only and for me only: it is how the desk deploys this machine.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "v1cferr" ];
    };
  };

  # Limine signs with keys it generates at the install, since a new machine has none. They are
  # NOT enrolled: Secure Boot stays off in the firmware until that is done by hand.
  boot.loader.limine.secureBoot.autoGenerateKeys = true;

  # Fixed at the 1st install: NEVER change it afterwards.
  system.stateVersion = "26.05";
}
