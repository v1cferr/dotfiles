# The Razer DeathAdder V2: hidraw access for the user, since there is NO kernel driver involved.
# Why openrazer is out (it does not build on 7.1+) and the protocol: docs/notes/hardware/razer.md
{ pkgs, ... }:

let
  # 60- and NOT services.udev.extraRules: that lands in 99-local.rules, and the tag would be set
  # AFTER 73-seat-late.rules already decided who gets an ACL. The note has the measurement.
  rules = pkgs.writeTextFile {
    name = "razer-hidraw-udev-rules";
    destination = "/etc/udev/rules.d/60-razer.rules";
    # uaccess, not a group: the ACL goes to whoever is PHYSICALLY logged in on the seat, which is
    # tighter than openrazer's plugdev-style group and leaves no group membership to maintain.
    text = ''
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1532", ATTRS{idProduct}=="0084", TAG+="uaccess"
    '';
  };
in
{
  # `razer-dpi get` for diagnosis. The watcher that pushes the OSD is a USER unit
  # (home/services/razer-dpi.nix), since `qs ipc` only exists inside the graphical session.
  environment.systemPackages = [ pkgs.razer-dpi ];

  services.udev.packages = [ rules ];
}
