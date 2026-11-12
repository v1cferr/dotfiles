# The shell's FEATURE FLAGS and host facts, read by Theme.qml through a generated JSON like the
# palette: which surfaces are on, and what this host can offer them. docs/notes/desktop/control-center.md
{
  config,
  lib,
  osConfig,
  ...
}:

{
  options.my.shell.controlCenter.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "The Control Center: the bar's entry point and its panel. Off, the bar keeps its own items and nothing else changes.";
  };

  options.my.shell.island.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "The island around the bar's logo: volume, a notification, a VPN, a track change. Off, the bottom OSD and the toasts do what they always did.";
  };

  config.home.file.".config/theme/shell.json".text = builtins.toJSON {
    controlCenter = config.my.shell.controlCenter.enable;
    island = config.my.shell.island.enable;
    # A fact, not a wish: the `vpn` CLI and its units exist only where a host imports vpn.nix.
    vpn = osConfig.systemd.services ? "vpn-fai";
  };
}
