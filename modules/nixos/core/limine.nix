# LIMINE: the candidate bootloader, active only under my.boot.loader = "limine". Secure Boot with
# the EXISTING sbctl keys and an enrolled, hashed config. The trust chain: docs/notes/boot-and-storage/boot.md
{ config, lib, ... }:

let
  cfg = config.my.boot;
  p = cfg.themePackage.preset;
in
{
  options.my.boot.windows.efiPartUuid = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "8f36a7a5-a54c-4c78-9d3d-1202514df9be";
    description = "GPT PARTUUID of the ESP holding Windows Boot Manager. Set by the host; null = no entry.";
  };

  config = lib.mkIf (cfg.loader == "limine") {
    boot.loader.limine = {
      enable = true;
      maxGenerations = 10; # the same rollback depth GRUB had

      # Forces enrollConfig, validateChecksums, panicOnChecksumMismatch and the editor OFF. Key
      # generation and enrollment stay OFF: the keys in /var/lib/sbctl are the ones in the firmware.
      secureBoot.enable = true;

      style = {
        wallpapers = [ "${cfg.themePackage}/limine/wallpaper.png" ];
        wallpaperStyle = "centered";
        backdrop = p.bg; # the same color around the canvas if the firmware picks another mode
        interface = {
          resolution = "1920x1080";
          branding = "NixOS";
          brandingColor = p.text;
          helpColor = p.dim;
          helpColorBright = p.accent;
        };
        graphicalTerminal = {
          font.scale = "2x2"; # the built-in 8x16 font is unreadable at 1080p without it
          palette = lib.concatStringsSep ";" [
            p.track
            p.red
            p.green
            p.yellow
            p.blue
            p.magenta
            p.cyan
            p.subtext
          ];
          brightPalette = lib.concatStringsSep ";" [
            p.dim
            p.red
            p.green
            p.yellow
            p.accent
            p.magenta
            p.cyan
            p.text
          ];
          foreground = p.subtext;
          brightForeground = p.text;
          background = "ff${p.bg}"; # fully transparent: the cells must not paint over the logo
          brightBackground = p.track;
          margin = 0;
          marginGradient = 0;
        };
      };

      # CHAINLOAD, not efi_boot_entry: that one sets BootNext and reboots, so it depends on the NVRAM
      # entry and costs a POST. The firmware still verifies bootmgfw.efi against db (Microsoft CA).
      extraEntries = lib.optionalString (cfg.windows.efiPartUuid != null) ''
        /Windows 11
            comment: Windows Boot Manager on its own disk
            protocol: efi
            path: guid(${cfg.windows.efiPartUuid}):/EFI/Microsoft/Boot/bootmgfw.efi
      '';
    };
  };
}
