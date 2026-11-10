# The t480s's hardware: the model profile, its CPU, kernel modules and the built-in panel.
# modules/ offers device modules; the host picks them: docs/notes/repo/flake.md
{ inputs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    # Intel graphics, TRIM, the TrackPoint and `throttled`, which lifts this model's low power limit.
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480s
  ];

  hardware.cpu.intel.updateMicrocode = true; # an i7-8650U

  # 2 builds x 4 cores = the 8 threads, and 12 GiB of RAM does not carry a third compiler.
  nix.settings.max-jobs = 2;
  nix.settings.cores = 4;

  # MONITORS: the panel, and the HDMI port for whatever gets plugged in (it may stay empty).
  my.monitors = {
    primary = "eDP-1"; # the built-in 14" panel, 1920x1080
    secondary = "HDMI-A-1";
    primaryName = "Panel";
    secondaryName = "HDMI";
  };

  # The passphrase prompt and a later TPM2 enrollment (`systemd-cryptenroll`) both want this.
  boot.initrd.systemd.enable = true;

  # From `nixos-generate-config` on the machine (10/11/2026).
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "uas"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];
}
