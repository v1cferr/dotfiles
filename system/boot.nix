# ═══════════════════════════════════════════════════════════════════════════
# BOOT — bootloader UEFI (systemd-boot). Kernel/initrd específicos do disco
# ficam no host (hosts/<host>/default.nix).
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 10; # ESP não enche de gerações
}
