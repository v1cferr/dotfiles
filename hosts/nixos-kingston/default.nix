# Host: nixos-kingston — MESMA máquina física (MOBO ASUS EX-B560M-V5), rodando do
# NVMe Kingston KC3000. É o DAILY DRIVER definitivo: o disco mais rápido fica com o
# sistema que se usa todo dia, e o SanDisk (SATA) vira Windows 11 depois.
# Só o específico; o comum vem de ../system. Disco DECLARATIVO via disko (btrfs).
# PREPARAÇÃO — nada é formatado num rebuild normal; só no cutover (ver disko.nix).
{ modulesPath, ... }:

{
  imports = [
    ./disko.nix # disko gera os fileSystems do Kingston (btrfs + subvolumes)
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  networking.hostName = "nixos-kingston";

  # ═══ MAPA DE DISCOS (MOBO EX-B560M-V5) — montagens extras ════════════════════
  # A raiz e o /boot vêm do disko. Aqui fica o ACESSO aos outros discos.
  # Sempre por UUID (sdX/nvmeX embaralham entre boots). Todos com nofail (não falha
  # o boot se o disco sumir) + x-systemd.device-timeout=5s: SEM o timeout o systemd
  # espera 90s pelo device ausente e TRAVA o `nixos-rebuild switch`.

  # Seagate (HDD) — destino do backup restic off-disk. Ver system/services/restic.nix.
  fileSystems."/mnt/seagate-old" = {
    device = "/dev/disk/by-uuid/85788f24-b8a0-4c3e-af4f-8af1f8b52147";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.device-timeout=5s" ];
  };

  # SanDisk (ex-sistema) — TRANSITÓRIO. Existe só pra copiar o /home disco-a-disco
  # depois da instalação. Quando o SanDisk virar Windows 11, o UUID muda e este mount
  # simplesmente não monta (nofail) — aí APAGUE este bloco em vez de deixá-lo mentindo.
  fileSystems."/mnt/sandisk-old" = {
    device = "/dev/disk/by-uuid/d0392422-6a6c-4c36-8ff4-e6eda25ae487";
    fsType = "ext4";
    options = [ "nofail" "x-systemd.device-timeout=5s" ];
  };

  # Scrub mensal: btrfs guarda checksum de TODO bloco, e o scrub é o que efetivamente
  # relê e compara. Sem ele o checksum só acusa erro quando você por acaso lê o setor
  # podre. Em ext4 isso não existia — é ganho novo, então vale ligar de saída.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # Kernel — MESMO hardware do SanDisk (mesma MOBO/CPU); só a raiz virou NVMe.
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];

  # Fixado na 1ª instalação — NUNCA mudar depois. Mesmo valor do host antigo porque
  # é a mesma release; o stateVersion acompanha a instalação, não o disco.
  system.stateVersion = "26.05";
}
