# ═══════════════════════════════════════════════════════════════════════════
# BOOT (GRUB + tema Minecraft) — ALTERNATIVA PRÉ-CONFIGURADA, DORMENTE.
#
# Este arquivo NÃO é importado por padrão (o system/default.nix importa ./boot.nix
# = systemd-boot). Ele fica pronto pra a migração systemd-boot → GRUB.
#
# ⚠️ ATIVAR SÓ EM CASA (na frente da máquina): trocar o bootloader errado deixa a
# máquina sem boot E sem SSH. Passos:
#   1. system/default.nix: troque `./boot.nix` por `./boot-grub.nix` no imports.
#   2. `nixos-rebuild build --flake .#nixos-sandisk`  (valida, não aplica)
#   3. `sudo nixos-rebuild switch --flake .#nixos-sandisk`
# O GRUB gera entradas das gerações anteriores do NixOS (rollback pelo menu) +
# o Arch (Kingston) via os-prober. Fallback: bootar geração anterior / live USB.
#
# Objetivo: bootar o Arch do Kingston pelo menu enquanto a migração 100% pro
# Kingston não acontece; e já deixar a base do dualboot final (+ Windows 11).
# ═══════════════════════════════════════════════════════════════════════════
{ inputs, ... }:

{
  imports = [ inputs.minegrub-world-sel-theme.nixosModules.default ];

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev"; # instala o GRUB-EFI no ESP (não num MBR)
    useOSProber = true; # detecta o Arch (Kingston) → boota ele pelo menu
    configurationLimit = 10; # ESP não enche de gerações
    minegrub-world-sel.enable = true; # tema "seleção de mundo" do Minecraft (dualboot)
  };
}
