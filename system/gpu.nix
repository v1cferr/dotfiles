# ═══════════════════════════════════════════════════════════════════════════
# GPU — Intel Arc B580 (Battlemage), driver open-source `xe` + Mesa. Máquina:
# Intel i5-11400 + Arc B580. Driver ÚNICO, declarativo, sem CUDA.
#
# Histórico: este host já rodou uma RTX 3050 (proprietário + CUDA) com uma
# specialisation de resgate durante a troca de placa. A Arc foi validada
# (fastfetch/vainfo/`xe` carregado) e a NVIDIA foi REMOVIDA de vez — o destino
# sempre foi Intel puro. Pra ressuscitar a NVIDIA, o histórico git deste arquivo
# tem o perfil completo. O Ollama segue esta GPU (ai/ollama.nix).
#
# Requisitos Battlemage já satisfeitos: kernel 6.18 (>=6.12), Mesa 25.x (>=24.3),
# firmware redistribuível ligado (hardware.nix).
# Ref: https://www.phoronix.com/review/intel-arc-b580-graphics-linux
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

{
  hardware.graphics.enable = true; # OpenGL/Vulkan (ex-hardware.opengl)
  hardware.graphics.enable32Bit = true; # libs 32-bit p/ Wine/Proton (Bottles/WoW)

  # X (LightDM) usa modesetting/KMS; Wayland/Hyprland vai direto no KMS.
  services.xserver.videoDrivers = [ "modesetting" ];
  boot.initrd.kernelModules = [ "xe" ]; # KMS cedo → tela sobe lisa, sem tela preta
  # Arc + warm reboot: num `reboot` quente a Arc pode não re-inicializar e travar
  # o POST (logo ASUS). `reboot=pci` força reset completo via 0xCF9 → o firmware
  # re-inicializa a GPU limpa, como num cold boot. Se não colar: bios/efi/acpi/cold.
  boot.kernelParams = [ "reboot=pci" ];

  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver # VA-API (iHD) — decode/encode de vídeo
    vpl-gpu-rt # oneVPL runtime (QuickSync nas gerações novas)
    intel-compute-runtime # OpenCL / Level Zero (compute)
  ];
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD"; # força o driver VA-API certo
  environment.systemPackages = [ pkgs.libva-utils ]; # `vainfo` p/ confirmar a aceleração
}
