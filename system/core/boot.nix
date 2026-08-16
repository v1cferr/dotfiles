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

  # A MAINLINE KERNEL (7.1.x) instead of the release default (6.18.x). The reason is the VIDEO
  # DRIVER: the Arc B580's `xe` lives in the kernel, so a new kernel means a new driver, and it
  # is the only driver lever that does NOT require crossing channels (`linuxPackages_latest`
  # comes from 26.05 itself). See the warning block in hardware/gpu.nix for why the rest of the
  # graphics stack stays on stable.
  # It is safe here because: zero out-of-tree modules (no zfs or virtualbox to version match)
  # and this machine's Secure Boot signs GRUB, not the kernel (./secureboot.nix), so changing
  # kernels does not ask for a key re-enroll.
  # PREFER `nixos-rebuild boot` plus a reboot when changing kernel versions, but `switch` does
  # NOT break it: NixOS keeps `/run/booted-system/kernel-modules` with the tree of the RUNNING
  # kernel, so modprobe and udev keep resolving (verified on 06/08/2026: a switch from 6.18.42
  # to 7.1.6 with zero failing services).
  # The advantage of `boot` is only not restarting a service inside a generation whose kernel
  # has not come up yet. Rollback is the previous generation in the GRUB menu.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev"; # installs GRUB-EFI on the ESP (not into an MBR)
    configurationLimit = 10; # generations in the menu (rollback) without filling the ESP

    # OS-PROBER OFF, with Windows pinned by hand right below. It WORKED (it found the
    # SanDisk's `bootmgfw.efi` on the first try), but it found TOO MUCH: the Seagate
    # (ST9320423AS) still has the old NixOS root. Today that disk is only the restic
    # destination, and the old system is still there because it cannot be formatted without
    # losing the backups. The result was a third entry booting a dead system.
    # Trading probing for a UUID solves that by CONSTRUCTION, and on top of it: the switch
    # stops mounting somebody else's disk (it was the slowest step and the only one with a side
    # effect) and the menu becomes genuinely declarative (rule 3) instead of depending on what
    # a scan finds on that boot.
    # THE PRICE, stated: if Windows is reinstalled or moves disks, the UUID changes and the
    # entry breaks silently (it disappears from the menu). os-prober would adapt on its own.
    # It is a ONE-line edit, and it is already on the radar, since the plan is to move Windows
    # to a new NVMe. Check with `lsblk -o NAME,LABEL,UUID`.
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

    # "auto" lets GRUB choose by EDID, and here there is a TV on HDMI besides the monitor: the
    # wrong mode means a stretched theme or a menu on the powered-off screen. A list with a
    # fallback: GRUB tries in order and only falls back to "auto" if the GOP does not offer
    # 1080p.
    gfxmodeEfi = "1920x1080,auto";

    # ═══ WHAT MAKES GRUB BOOT WITH SECURE BOOT ON ════════════════════════════
    # Without these two flags the result is `error: prohibited by secure boot policy` plus
    # `grub rescue>`, measured on 02/08/2026, on the first attempt. The firmware ACCEPTED the
    # signed grubx64.efi (the signature was right); what refused was GRUB, against itself.
    # There are two distinct blocks:
    #
    # 1. `--modules=…`: with Secure Boot active GRUB disables `insmod` (it is code side-load).
    #    Since `grub-install` embeds only the minimum needed to find /boot, `normal` (the
    #    module that DRAWS THE MENU) came from the disk and was blocked, so it went straight to
    #    rescue, before any menu. Everything the boot needs has to be INSIDE the signed binary.
    #    The names were checked one by one against grub2_efi: all 47 exist.
    #
    # 2. `--disable-shim-lock`: this is the non-obvious one, and embedding modules ALONE would
    #    not solve it. The menu would appear and then BOTH NixOS AND Windows would fail. In
    #    kern/efi/sb.c, `grub_shim_lock_verifier_setup()` only does NOT register the verifier in
    #    two cases: Secure Boot off, or the image carrying the OBJ_TYPE_DISABLE_SHIM_LOCK marker
    #    (which is what this flag embeds). Once registered, it covers
    #    GRUB_FILE_TYPE_LINUX_KERNEL and GRUB_FILE_TYPE_EFI_CHAINLOADED_IMAGE, and its `write`
    #    calls the shim protocol, which here DOES NOT EXIST, because we use no shim, so every
    #    boot dies in "shim_lock protocol not found".
    #
    # Flag 2 is literally "do not verify anything after me", and it is what makes concrete the
    # caveat already documented in ./secureboot.nix: the chain is verified by the firmware UP TO
    # GRUB, and not beyond. Whoever wants more than that needs a shim (and then a
    # Microsoft-signed kernel) or lanzaboote (and then no menu and no theme). There is no third
    # door.
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
        # Old generations. In en-US like the rest of the system UI (the pt-BR exception is only
        # the lockscreen), and it overrides the theme's default text, which is a "Select To
        # Enter" that does not say what is in there.
        name = "submenu";
        imgName = "submenu";
        lineTop = "Older Generations";
        lineBottom = "Spectator Mode, Rollback";
      }
    ];
  };

  # NTFS support: the `ntfs3` driver already ships in the kernel, but what `mount` looks for is
  # the userspace helper `mount.ntfs-3g`, which only exists with this option. Kept after the
  # dualboot was done so the Windows disk can be read on demand (a manual mount; there is no
  # permanent mount of it, see hosts/nixos-kingston).
  boot.supportedFilesystems.ntfs = true;
}
