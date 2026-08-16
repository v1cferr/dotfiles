# GPU: an Intel Arc B580 (Battlemage) on the open source `xe` driver plus Mesa, no CUDA.
# Why extraPackages must NOT go unstable, and why Mesa is the exception: docs/notes/hardware/gpu.md
{ pkgs, ... }:

{
  hardware.graphics.enable = true; # OpenGL/Vulkan (formerly hardware.opengl)
  hardware.graphics.enable32Bit = true; # 32-bit libs for Wine/Proton (Bottles/WoW)

  # X (LightDM) uses modesetting/KMS; Wayland/Hyprland goes straight to KMS.
  services.xserver.videoDrivers = [ "modesetting" ];
  boot.initrd.kernelModules = [ "xe" ]; # KMS early, so the screen comes up smooth, with no black screen
  # `reboot=pci`: on a hot reboot the Arc can freeze the POST at the ASUS logo; 0xCF9 forces a
  # full reset, so the firmware reinitializes it clean. If it stops sticking: bios/efi/acpi/cold.
  boot.kernelParams = [ "reboot=pci" ];

  # Do NOT swap these for `pkgs.unstable.*`: TESTED AND REJECTED (06/08/2026). They are PLUGINS
  # loaded by a STABLE loader that refuses a NEWER driver, and it fails silently. See the notes.
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver # VA-API (iHD): video decode/encode
    vpl-gpu-rt # the oneVPL runtime (QuickSync on the newer generations)
    intel-compute-runtime # OpenCL / Level Zero (compute)
  ];
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD"; # it forces the right VA-API driver
  environment.systemPackages = [ pkgs.libva-utils ]; # `vainfo`, to confirm the acceleration
}
