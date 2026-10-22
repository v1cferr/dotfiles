# BOOT APPEARANCE: the palette the pre-boot screens wear (Limine, Plymouth) and the splash itself.
# Why a preset by NAME and what the splash may never hide: docs/notes/boot-and-storage/splash.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.boot;
  presets = import ../../home/desktop/palette-presets.nix;
in
{
  options.my.boot = {
    theme = lib.mkOption {
      type = lib.types.enum (lib.attrNames presets.presets);
      default = presets.default;
      description = "The palette preset of the bootloader menu and the splash (the desktop's own file).";
    };
    themePackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = pkgs.boot-theme.override { preset = presets.presets.${cfg.theme}; };
      description = "The rendered Limine wallpaper and Plymouth theme for my.boot.theme.";
    };
    splash.enable = lib.mkEnableOption "the Plymouth splash at boot, reboot and shutdown";
  };

  config = lib.mkIf cfg.splash.enable {
    boot.plymouth = {
      enable = true;
      theme = cfg.themePackage.name;
      themePackages = [ cfg.themePackage ];
    };
  };
}
