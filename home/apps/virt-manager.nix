# VIRT-MANAGER: the GUI only, pointed at the SYSTEM daemon. The daemon is system/services/libvirt.nix.
# Why NOT programs.virt-manager.enable, which is what the wiki says: docs/notes/services/libvirt.md
{
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs) virt-manager;

  enabled = osConfig.my.services.libvirt;
in
{
  home.packages = lib.mkIf enabled [ virt-manager ];

  # `qemu:///system` and NOT `qemu:///session`: the NAT and the emulated TPM belong to the system
  # daemon, and a session connection would silently get neither.
  dconf.settings = lib.mkIf enabled {
    "org/virt-manager/virt-manager/connections" = {
      uris = [ "qemu:///system" ];
      autoconnect = [ "qemu:///system" ];
    };
  };
}
