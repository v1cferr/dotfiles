# Jogos / launchers / emuladores (só o binário). As bottles, ROMs, instâncias e
# runners são ESTADO em ~/.local/share — não se declaram, vão pro backup (regra 6).
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Bottles (Wine/Proton) FHS-wrapped → runners GE-Proton/wine-staging rodam no
    # NixOS. removeWarningPopup: silencia o "Unsupported Environment" (upstream só
    # suporta Flatpak/sandbox; no NixOS é FHS-wrapped e funciona — o popup é ruído).
    (bottles.override { removeWarningPopup = true; })

    # RPCS3 — emulador de PS3 (trilogia Uncharted 1/2/3). Vulkan (Arc ok). Firmware
    # (PS3UPDAT.PUP da Sony) e jogos = ESTADO, você provê.
    rpcs3

    # PrismLauncher — Minecraft (open-source) p/ modpacks, roda NATIVO (sem Wine).
    # Vem wrapped com os JDKs (Java 8/17/21) → autodetecta o Java 21 do Minecraft
    # 1.21.1 + NeoForge, sem config extra.
    prismlauncher
  ];
}
