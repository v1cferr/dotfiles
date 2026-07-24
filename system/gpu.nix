# ═══════════════════════════════════════════════════════════════════════════
# GPU — driver de vídeo por PERFIL. Máquina destino: Intel i5-11400 + Arc B580.
#
# `my.gpu` escolhe quem dá vídeo:
#   "intel" (DEFAULT) → Arc B580 (Battlemage), open-source `xe` + Mesa (sem CUDA).
#   "nvidia"          → RTX 3050 Ampere, proprietário + CUDA (RESGATE, temporário).
#
# Estamos TROCANDO a RTX 3050 pela Arc B580. Por isso o Intel é o default: ao
# plugar a Arc e ligar, o boot padrão já dá vídeo — sem menu, sem configurar nada.
# A NVIDIA fica como specialisation "nvidia" (entrada separada no systemd-boot, que
# desenha via framebuffer EFI em qualquer placa) só como REDE DE SEGURANÇA: se a
# Arc não der vídeo, recoloca a RTX + escolhe a entrada "nvidia" (ou boota uma
# geração anterior). Depois de confirmar a Arc (fastfetch/vainfo), REMOVER de vez o
# perfil nvidia e este switch — o destino é Intel puro. Só UM driver por boot
# (blocos mkIf exclusivos, sem mkForce). O Ollama segue a GPU (ai/ollama.nix).
#
# Requisitos Battlemage já satisfeitos: kernel 6.18 (>=6.12), Mesa 25.x (>=24.3),
# firmware redistribuível ligado (hardware.nix).
# Ref: https://www.phoronix.com/review/intel-arc-b580-graphics-linux
# ═══════════════════════════════════════════════════════════════════════════
{ config, lib, pkgs, ... }:

let
  cfg = config.my.gpu;
in
{
  options.my.gpu = lib.mkOption {
    type = lib.types.enum [ "nvidia" "intel" ];
    default = "intel";
    description = "GPU que dá vídeo. A specialisation nvidia é o resgate temporário.";
  };

  config = lib.mkMerge [
    # ── Comum às duas placas ───────────────────────────────────────────────────
    {
      hardware.graphics.enable = true; # OpenGL/Vulkan (ex-hardware.opengl)
      hardware.graphics.enable32Bit = true; # libs 32-bit p/ Wine/Proton (Bottles/WoW)
    }

    # ── Intel Arc B580 (Battlemage) — open-source xe + Mesa ─────────────────────
    (lib.mkIf (cfg == "intel") {
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

      # Entrada de boot de RESGATE p/ a NVIDIA. Fica DENTRO do perfil intel (não é
      # definida quando já estamos no nvidia) → sem recursão de specialisation.
      specialisation.nvidia.configuration.my.gpu = "nvidia";
    })

    # ── NVIDIA RTX 3050 (Ampere) — proprietário (resgate temporário) ────────────
    # nouveau em Ampere não faz reclocking (lento) e não tem CUDA; o proprietário
    # com módulos ABERTOS é o recomendado p/ Turing+ e p/ Wayland+Vulkan+CUDA.
    (lib.mkIf (cfg == "nvidia") {
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia = {
        modesetting.enable = true; # obrigatório p/ Wayland/Hyprland
        open = true; # módulos abertos (Ampere suporta; recomendado)
        nvidiaSettings = true; # app gráfico nvidia-settings
        package = config.boot.kernelPackages.nvidiaPackages.stable;
      };
    })
  ];
}
