# ═══════════════════════════════════════════════════════════════════════════
# BOOT — GRUB (UEFI) com tema minegrub, em DUALBOOT com o Windows 11.
#
# POR QUE GRUB, e não o systemd-boot que estava aqui até ago/2026: cada sistema tem
# a SUA ESP, em disco separado — NixOS em `nvme0n1p1` (/boot) e Windows 11 em `sdb1`
# (SanDisk). O systemd-boot só carrega binário EFI da PRÓPRIA ESP, então ele é
# incapaz de listar o Windows: trocar de SO viraria F8 no POST toda vez. O GRUB lê
# as duas. Isso também é o que descarta o lanzaboote (o caminho oficial de Secure
# Boot no NixOS), que é systemd-boot-only — a assinatura mora em ./secureboot.nix.
#
# ⚠️ OS ÍCONES DO TEMA CASAM POR `--class`, NÃO PELO TÍTULO DA ENTRADA. É a única
# pegadinha real aqui, e ela falha em SILÊNCIO (cai num ícone genérico sem texto):
#   • `nixos`   vem do default `entryOptions = "--class nixos --unrestricted"`;
#   • `windows` é derivado pelo 30_os-prober a partir do LABEL "Windows Boot
#     Manager" — ele pega a PRIMEIRA palavra em minúsculas (grub2/etc/grub.d/
#     30_os-prober:149), então o nome certo é "windows", nunca "windows11";
#   • `submenu` é o das gerações antigas (install-grub.pl emite `--class submenu`).
# Cada `name` do customIcons vira o arquivo `icons/<name>.png` do tema, e o texto
# das duas linhas é RENDERIZADO DENTRO do PNG na fonte do Minecraft — não é texto
# do GRUB. Por isso todas as gerações mostram a mesma descrição: elas compartilham
# a classe `nixos`. É limitação do tema, não erro de config.
#
# Os kernels são copiados pra ESP automaticamente (install-grub.pl:107 liga o
# copyKernels quando /boot está em outro filesystem que /nix/store) — o que evita
# depender do GRUB saber ler btrfs+zstd. O arquivo é nomeado pelo hash da store,
# então gerações que compartilham kernel ocupam espaço UMA vez: os 10 limites cabem
# folgados no 1 GiB da ESP (hoje: 13 MiB de kernel + 47 MiB de initrd por versão).
# ═══════════════════════════════════════════════════════════════════════════
{ config, inputs, ... }:

{
  imports = [ inputs.minegrub-world-sel-theme.nixosModules.default ];

  boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev"; # instala o GRUB-EFI na ESP (não num MBR)
    useOSProber = true; # varre os outros discos e põe o Windows 11 no menu
    configurationLimit = 10; # gerações no menu (rollback) sem encher a ESP

    # O tema desenha o próprio fundo. O default do NixOS (wallpaper cinza) só
    # apareceria por um frame atrás dele e ainda copiaria 1 MiB inútil pra ESP.
    splashImage = null;

    # "auto" deixa o GRUB escolher pelo EDID, e aqui há uma TV no HDMI além do
    # monitor: modo errado = tema esticado ou menu na tela apagada. Lista com
    # fallback — o GRUB tenta em ordem e só cai no "auto" se o GOP não oferecer 1080p.
    gfxmodeEfi = "1920x1080,auto";

    minegrub-world-sel.enable = true;
    minegrub-world-sel.customIcons = [
      {
        name = "nixos"; # = --class de entryOptions
        imgName = "nixos";
        lineTop = "NixOS ${config.system.nixos.release} (${config.system.nixos.codeName})";
        lineBottom = "Survival Mode, No Cheats";
      }
      {
        name = "windows"; # = --class que o 30_os-prober deriva do LABEL
        imgName = "windows11";
        lineTop = "Windows 11 (SanDisk SSD PLUS)";
        lineBottom = "Creative Mode, Cheats Enabled";
      }
      {
        # Gerações antigas. Em en-US como todo o resto da UI do sistema (a exceção
        # pt-BR é só a lockscreen) — e sobrescreve o texto default do tema, que é
        # um "Select To Enter" que não diz o que tem lá dentro.
        name = "submenu";
        imgName = "submenu";
        lineTop = "Older Generations";
        lineBottom = "Spectator Mode, Rollback";
      }
    ];
  };

  # Suporte a NTFS — o driver `ntfs3` já vem no kernel, mas o que o `mount` procura
  # é o helper de userspace `mount.ntfs-3g`, que só existe com esta opção. Mantido
  # depois do dualboot pronto pra conseguir ler o disco do Windows sob demanda
  # (montagem manual; nenhum mount permanente dele — ver hosts/nixos-kingston).
  boot.supportedFilesystems.ntfs = true;
}
