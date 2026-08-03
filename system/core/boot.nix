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
#   • `windows` vem do `--class windows` escrito à mão no extraEntries abaixo;
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
    configurationLimit = 10; # gerações no menu (rollback) sem encher a ESP

    # OS-PROBER DESLIGADO, Windows fixado à mão logo abaixo. Ele FUNCIONAVA (achou o
    # `sdb1@/efi/Microsoft/Boot/bootmgfw.efi` de primeira), mas achava DEMAIS: o
    # Seagate (`sda2`) ainda tem a raiz do NixOS antigo — hoje o disco é só o destino
    # do restic, e o sistema velho continua lá porque não dá pra formatar sem perder
    # os backups. Resultado: uma terceira entrada que boota um sistema morto.
    # Trocar sondagem por UUID resolve isso por CONSTRUÇÃO, e ainda: o switch deixa de
    # montar disco alheio (era o passo mais lento e o único com efeito colateral) e o
    # menu passa a ser declarativo de verdade (regra 3) em vez de depender do que uma
    # varredura encontrar naquele boot.
    # PREÇO, explícito: se o Windows for reinstalado ou mudar de disco, o UUID muda e
    # a entrada quebra em silêncio (some do menu). O os-prober se adaptaria sozinho.
    # É edição de UMA linha, e já está no radar — o plano é mover o Windows pra um
    # NVMe novo. Conferir com `lsblk -o NAME,LABEL,UUID`.
    useOSProber = false;
    extraEntries = ''
      menuentry "Windows 11" --class windows --class os {
        insmod part_gpt
        insmod fat
        insmod chain
        search --no-floppy --fs-uuid --set=root 904C-B9D0
        chainloader /EFI/Microsoft/Boot/bootmgfw.efi
      }
    '';

    # O tema desenha o próprio fundo. O default do NixOS (wallpaper cinza) só
    # apareceria por um frame atrás dele e ainda copiaria 1 MiB inútil pra ESP.
    splashImage = null;

    # "auto" deixa o GRUB escolher pelo EDID, e aqui há uma TV no HDMI além do
    # monitor: modo errado = tema esticado ou menu na tela apagada. Lista com
    # fallback — o GRUB tenta em ordem e só cai no "auto" se o GOP não oferecer 1080p.
    gfxmodeEfi = "1920x1080,auto";

    # ═══ O QUE FAZ O GRUB BOOTAR COM SECURE BOOT LIGADO ═══════════════════════
    # Sem estas duas flags o resultado é `error: prohibited by secure boot
    # policy` + `grub rescue>` — medido em 02/08/2026, na primeira tentativa.
    # A firmware ACEITOU o grubx64.efi assinado (a assinatura estava certa); quem
    # recusou foi o GRUB, contra si mesmo. São dois bloqueios distintos:
    #
    # 1. `--modules=…` — com Secure Boot ativo o GRUB desliga o `insmod` (é
    #    side-load de código). Como o `grub-install` embute só o mínimo pra achar
    #    o /boot, o `normal` (o módulo que DESENHA O MENU) vinha do disco e era
    #    barrado → rescue direto, antes de qualquer menu. Tudo que o boot precisa
    #    tem que estar DENTRO do binário assinado. Nomes conferidos um a um contra
    #    o grub2_efi: os 47 existem.
    #
    # 2. `--disable-shim-lock` — esta é a não-óbvia, e embutir módulos SOZINHO não
    #    resolveria: o menu apareceria e aí falhariam o NixOS E o Windows. Em
    #    kern/efi/sb.c, o `grub_shim_lock_verifier_setup()` só NÃO registra o
    #    verificador em dois casos: Secure Boot desligado, ou a imagem trazer o
    #    marcador OBJ_TYPE_DISABLE_SHIM_LOCK (que é o que esta flag embute).
    #    Registrado, ele cobre GRUB_FILE_TYPE_LINUX_KERNEL e
    #    GRUB_FILE_TYPE_EFI_CHAINLOADED_IMAGE, e o `write` dele chama o protocolo
    #    do shim — que aqui NÃO EXISTE, porque não usamos shim → todo boot morre
    #    em "shim_lock protocol not found".
    #
    # ⚠️ A flag 2 é literalmente "não verifique nada depois de mim", e é o que
    # torna concreto o caveat já documentado em ./secureboot.nix: a cadeia é
    # verificada pela firmware ATÉ o GRUB, e não além. Quem quiser além disso
    # precisa de shim (e aí kernel assinado pela Microsoft) ou do lanzaboote (e
    # aí sem menu e sem tema). Não há terceira porta.
    extraGrubInstallArgs = [
      "--disable-shim-lock"
      (
        "--modules="
        + builtins.concatStringsSep " " [
          "all_video"
          "boot"
          "btrfs"
          "cat"
          "chain"
          "configfile"
          "echo"
          "efifwsetup"
          "efi_gop"
          "efi_uga"
          "ext2"
          "fat"
          "font"
          "gettext"
          "gfxmenu"
          "gfxterm"
          "gfxterm_background"
          "gzio"
          "halt"
          "help"
          "jpeg"
          "keystatus"
          "linux"
          "loadenv"
          "loopback"
          "ls"
          "lsefi"
          "minicmd"
          "normal"
          "part_gpt"
          "part_msdos"
          "png"
          "probe"
          "reboot"
          "regexp"
          "search"
          "search_fs_file"
          "search_fs_uuid"
          "search_label"
          "sleep"
          "terminal"
          "test"
          "true"
          "video"
          "video_fb"
          "videoinfo"
          "zstd"
        ]
      )
    ];

    minegrub-world-sel.enable = true;
    minegrub-world-sel.customIcons = [
      {
        name = "nixos"; # = --class de entryOptions
        imgName = "nixos";
        lineTop = "NixOS ${config.system.nixos.release} (${config.system.nixos.codeName})";
        lineBottom = "Survival Mode, No Cheats";
      }
      {
        name = "windows"; # = --class da entrada em extraEntries
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
