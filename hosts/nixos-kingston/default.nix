# Host: nixos-kingston — MOBO ASUS EX-B560M-V5, rodando do NVMe Kingston KC3000.
# É o DAILY DRIVER (cutover feito em 01/08/2026): o disco mais rápido ficou com o
# sistema de todo dia, e o SanDisk (SATA) virou o Windows 11 do dualboot.
# Só o específico; o comum vem de ../system. Disco DECLARATIVO via disko (btrfs).
# Nada é formatado num rebuild normal — só num `disko` explícito (ver disko.nix).
{ modulesPath, ... }:

{
  imports = [
    ./disko.nix # disko gera os fileSystems do Kingston (btrfs + subvolumes)
    ./services.nix # PAINEL: quais serviços opcionais esta máquina liga (my.services.*)
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  networking.hostName = "nixos-kingston";

  # ═══ MONITORES — conectores DESTA placa/GPU ═══════════════════════════════
  # SSOT dos nomes; a opção é declarada em system/desktop/monitors.nix (sem default,
  # de propósito) e lida por Nix, Lua e QML. Trocar de cabo/monitor = trocar AQUI.
  my.monitors = {
    primary = "DP-2"; # LG ULTRAGEAR (DisplayPort)
    secondary = "HDMI-A-3"; # TV LG (HDMI)
  };

  # ═══ MAPA DE DISCOS (MOBO EX-B560M-V5) — montagens extras ════════════════════
  # A raiz e o /boot vêm do disko. Aqui fica o ACESSO aos outros discos.
  # Sempre por UUID (sdX/nvmeX embaralham entre boots). Todos com nofail (não falha
  # o boot se o disco sumir) + x-systemd.device-timeout=5s: SEM o timeout o systemd
  # espera 90s pelo device ausente e TRAVA o `nixos-rebuild switch`.

  # Seagate (HDD) — destino do backup restic off-disk. Ver system/services/restic.nix.
  fileSystems."/mnt/seagate-old" = {
    device = "/dev/disk/by-uuid/85788f24-b8a0-4c3e-af4f-8af1f8b52147";
    fsType = "ext4";
    options = [
      "nofail"
      "x-systemd.device-timeout=5s"
    ];
  };

  # O SanDisk NÃO é montado de propósito. Ele virou o Windows 11 (NTFS), e a única
  # partição que o NixOS precisa dele é a ESP — que o os-prober monta sozinho, na
  # hora do switch, pra pôr o Windows no menu do GRUB (ver system/core/boot.nix).
  # Montar o C: aqui seria convidar as duas coisas que estragam dualboot: escrita em
  # NTFS com hibernação/fast-startup pendente, e o restic varrendo 900 GB alheios.

  # O scrub mensal e o resto da POLÍTICA de btrfs (alarme, contadores de erro,
  # reclaim, TRIM, nocow) saíram daqui pra system/hardware/btrfs.nix: nada ali é
  # específico DESTA máquina — o guarda é "a raiz é btrfs?", não "é o Kingston?".
  # Aqui fica só o LAYOUT, que é do host de verdade (disko.nix).

  # Kernel — MESMO hardware do SanDisk (mesma MOBO/CPU); só a raiz virou NVMe.
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  # Fixado na 1ª instalação — NUNCA mudar depois. Mesmo valor do host antigo porque
  # é a mesma release; o stateVersion acompanha a instalação, não o disco.
  system.stateVersion = "26.05";
}
