# The Razer DeathAdder V2: hidraw access for the user, since there is NO kernel driver involved.
# Why openrazer is out (it does not build on 7.1+) and the protocol: docs/notes/hardware/razer.md
{ pkgs, ... }:

{
  # `razer-dpi get` for diagnosis. The watcher that pushes the OSD is a USER unit
  # (home/services/razer-dpi.nix), since `qs ipc` only exists inside the graphical session.
  environment.systemPackages = [ pkgs.razer-dpi ];

  # uaccess, not a group: the ACL goes to whoever is PHYSICALLY logged in on the seat, which is
  # tighter than openrazer's plugdev-style group and leaves no group membership to maintain.
  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1532", ATTRS{idProduct}=="0084", TAG+="uaccess"
  '';
}
