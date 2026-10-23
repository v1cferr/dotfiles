# BOOT APPEARANCE: the palette the pre-boot screens wear (Limine, Plymouth) and the splash itself.
# Why a preset by NAME and what the splash may never hide: docs/notes/boot-and-storage/splash.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    coreutils
    nerd-fonts
    writeShellApplication
    ;

  cfg = config.my.boot;
  presets = import ../../home/desktop/palette-presets.nix;

  # The pane's lines: what PID 1 logs (Started, Stopping, Failed to start...), each passed to the
  # splash as it is logged. systemd itself only tells Plymouth which units finished starting.
  feed = writeShellApplication {
    name = "plymouth-log-feed";
    runtimeInputs = [
      coreutils
      config.systemd.package
      config.boot.plymouth.package
    ];
    text = ''
      # The LOOP's exit is the verdict: when the splash goes, journalctl dies on a closed pipe, and
      # with pipefail that normal end would read as a failure (vm-limine caught it).
      set +o pipefail
      # Ask Plymouth itself: at shutdown it keeps no pid file where the boot one is (vm-limine).
      plymouth --ping || exit 0
      journalctl --follow --lines=8 --quiet --output=cat _PID=1 |
        while IFS= read -r line; do
          # Bookkeeping, not news: skipped conditions, CPU accounting, a clean exit, a signal.
          case "$line" in
            *"skipped, unmet condition"* | "Condition check resulted"* | *": Consumed "* | \
              *": Deactivated successfully." | "Received SIGRTMIN"*) continue ;;
          esac
          # Plymouth gone (the session took the screen) is the normal end, not a failure.
          if ! timeout 1 plymouth display-message --text="$line"; then
            echo "plymouth no longer answers: the splash is gone, stopping" >&2
            exit 0
          fi
        done
    '';
  };

  # Both instances run only while a splash answers (the script pings it), and never order
  # anything after themselves.
  feedUnit = {
    unitConfig.DefaultDependencies = false;
    serviceConfig.ExecStart = lib.getExe feed;
  };
in
{
  options.my.boot = {
    theme = lib.mkOption {
      type = lib.types.enum (lib.attrNames presets.presets);
      inherit (presets) default;
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
      # The desktop's UI family (my.fonts.ui), in its fixed-width cut so the pane's columns line up.
      font = "${nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFontMono-Regular.ttf";
    };

    # At boot: until the splash is gone, when display-message fails and the loop ends by itself.
    # NO Conflicts= on plymouth-quit: systemd drops the quit job instead and the boot waits forever.
    systemd.services.plymouth-log = lib.recursiveUpdate feedUnit {
      description = "Show systemd's own lines on the boot splash";
      wantedBy = [ "sysinit.target" ];
      after = [
        "systemd-journald.service"
        "plymouth-start.service"
      ];
    };

    # At reboot and poweroff: from the shutdown splash until the final SIGTERM ends it.
    systemd.services.plymouth-log-shutdown = lib.recursiveUpdate feedUnit {
      description = "Show systemd's own lines on the shutdown splash";
      wantedBy = [
        "reboot.target"
        "poweroff.target"
        "halt.target"
        "kexec.target"
      ];
      after = [
        "plymouth-reboot.service"
        "plymouth-poweroff.service"
        "plymouth-halt.service"
        "plymouth-kexec.service"
      ];
    };
  };
}
