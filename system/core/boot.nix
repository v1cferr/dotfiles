# BOOT: GRUB (UEFI) with the minegrub theme, dualbooting Windows 11 off a SECOND disk's ESP.
# Why GRUB and not systemd-boot, and the --class icon trap: docs/notes/boot.md
{
  config,
  inputs,
  pkgs,
  ...
}:

{
  imports = [ inputs.minegrub-world-sel-theme.nixosModules.default ];

  # A MAINLINE KERNEL (7.1.x), because the Arc's `xe` driver LIVES in the kernel and this is the
  # only driver lever that does not cross channels. Prefer `boot`, but `switch` is safe: the notes.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev"; # installs GRUB-EFI on the ESP (not into an MBR)
    configurationLimit = 10; # generations in the menu (rollback) without filling the ESP

    # OS-PROBER OFF, Windows pinned by UUID: probing also found the Seagate's DEAD NixOS root and
    # made a third entry. The price is a silent break if Windows moves: docs/notes/boot.md
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

    # The theme draws its own background. The NixOS default (a gray wallpaper) would only show
    # for one frame behind it and would still copy 1 useless MiB to the ESP.
    splashImage = null;

    # A LIST and not "auto": with a TV on HDMI, EDID can pick a mode that stretches the theme or
    # draws the menu on the powered-off screen. GRUB tries in order, falling back to auto.
    gfxmodeEfi = "1920x1080,auto";

    # THE 2 FLAGS THAT MAKE GRUB BOOT UNDER SECURE BOOT. Without them: `prohibited by secure boot
    # policy` plus `grub rescue>`, and GRUB is what refuses, not the firmware. Why: docs/notes/boot.md
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
        name = "nixos"; # matches the --class of entryOptions
        imgName = "nixos";
        lineTop = "NixOS ${config.system.nixos.release} (${config.system.nixos.codeName})";
        lineBottom = "Survival Mode, No Cheats";
      }
      {
        name = "windows"; # matches the --class of the entry in extraEntries
        imgName = "windows11";
        lineTop = "Windows 11 (SanDisk SSD PLUS)";
        lineBottom = "Creative Mode, Cheats Enabled";
      }
      {
        # Old generations. In en-US like the rest of the system UI, and it overrides the theme's
        # "Select To Enter", which does not say what is in there.
        name = "submenu";
        imgName = "submenu";
        lineTop = "Older Generations";
        lineBottom = "Spectator Mode, Rollback";
      }
    ];
  };

  # NTFS: the driver is in the kernel, but `mount` needs the userspace `mount.ntfs-3g`, which only
  # exists with this option. There is no permanent mount of the Windows disk.
  boot.supportedFilesystems.ntfs = true;
}
