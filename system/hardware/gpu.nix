# GPU: an Intel Arc B580 (Battlemage), the open source `xe` driver plus Mesa. The machine: an
# Intel i5-11400 plus an Arc B580. A SINGLE driver, declarative, with no CUDA.
#
# History: this host once ran an RTX 3050 (proprietary plus CUDA) with a rescue specialisation
# during the card swap. The Arc was validated (fastfetch/vainfo/`xe` loaded) and NVIDIA was
# REMOVED for good, since the destination was always pure Intel. To resurrect NVIDIA, this file's
# git history has the complete profile. Ollama runs ON THIS GPU, through Vulkan/Mesa ANV, so the
# Mesa here is a critical path for AI, not only for games (services/ollama.nix).
#
# The Battlemage requirements are already satisfied: kernel 6.18 (>=6.12), Mesa 25.x (>=24.3),
# redistributable firmware turned on (hardware.nix).
# Ref: https://www.phoronix.com/review/intel-arc-b580-graphics-linux
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

{
  hardware.graphics.enable = true; # OpenGL/Vulkan (formerly hardware.opengl)
  hardware.graphics.enable32Bit = true; # 32-bit libs for Wine/Proton (Bottles/WoW)

  # X (LightDM) uses modesetting/KMS; Wayland/Hyprland goes straight to KMS.
  services.xserver.videoDrivers = [ "modesetting" ];
  boot.initrd.kernelModules = [ "xe" ]; # KMS early, so the screen comes up smooth, with no black screen
  # Arc plus a warm reboot: on a hot `reboot` the Arc may fail to reinitialize and freeze the POST
  # (at the ASUS logo). `reboot=pci` forces a full reset through 0xCF9, so the firmware
  # reinitializes the GPU clean, like a cold boot. If that does not stick: bios/efi/acpi/cold.
  boot.kernelParams = [ "reboot=pci" ];

  # Do NOT swap this for `pkgs.unstable.*`: TESTED AND REJECTED (06/08/2026). These .so files are
  # not normal libs, they are PLUGINS loaded impurely from /run/opengl-driver/lib by a loader that
  # comes from the STABLE channel, and the loader accepts a driver EQUAL to or OLDER than itself,
  # never newer. `libva` scans `__vaDriverInit_1_<minor>` from ITS minor down to 1_0; unstable's
  # iHD exports `1_24` and stable's libva 2.23 only tries up to `1_23`, so `vaInitialize failed`
  # and all decode/encode falls back to the CPU, in silence.
  #
  # MESA is NOT covered by this rule; it is a MEASURED exception, not a guess: `libgbm` is a
  # separate package (a stub) and `hardware.graphics.package` exists precisely to change Mesa's
  # global version. Tested: `unstable.mesa`'s ICD plus the system's loader gave an Arc B580 with
  # `Mesa 26.1.6`, with no error. If it is ever worth it, that is where it goes (with
  # `package32 = pkgs.unstable.pkgsi686Linux.mesa`, IN THAT ORDER), not here.
  # Today it is not worth it: nixpkgs backports the point release into the release (mesa 26.1.5 vs
  # 26.1.6; the kernel and linux-firmware are IDENTICAL in both channels). For the kernel the lever
  # is `linuxPackages_latest`, from stable itself; see core/boot.nix.
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver # VA-API (iHD): video decode/encode
    vpl-gpu-rt # the oneVPL runtime (QuickSync on the newer generations)
    intel-compute-runtime # OpenCL / Level Zero (compute)
  ];
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD"; # it forces the right VA-API driver
  environment.systemPackages = [ pkgs.libva-utils ]; # `vainfo`, to confirm the acceleration
}
