# ═══════════════════════════════════════════════════════════════════════════
# BOOT — bootloader UEFI (systemd-boot, ATUAL). Kernel/initrd específicos do
# disco ficam no host (hosts/<host>/default.nix).
#
# Alternativa PRÉ-CONFIGURADA: ./boot-grub.nix (GRUB + tema minegrub + os-prober
# p/ bootar o Arch do Kingston). Pra migrar EM CASA: no system/default.nix troque
# o import `./boot.nix` por `./boot-grub.nix` e dê switch (ver o cabeçalho de lá).
# Fica em arquivo à parte (não em toggle) porque a opção do tema só existe quando
# o módulo do minegrub é importado — então o GRUB mora num arquivo que só é
# avaliado quando você o importa.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 10; # ESP não enche de gerações
}
