# The shell's FEATURE FLAGS and host facts, read by Theme.qml through a generated JSON like the
# palette: which surfaces are on, and what this host can offer them. docs/notes/desktop/quickshell.md
{
  config,
  lib,
  osConfig,
  ...
}:

{
  options.my.shell.island.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "The island around the bar's logo: volume, a notification, a VPN, a track change. Off, the bottom OSD and the toasts do what they always did.";
  };

  options.my.shell.bar.clear.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "The bar with no strip: its items sit on the wallpaper and only the island is a surface. Off, the continuous glass strip and its numbered workspaces come back.";
  };

  options.my.shell.island.glass.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "The open island, the NixOS Center, as see-through glass over the compositor's blur (hypr/lua gives its layer the rule). Off, it is opaque.";
  };

  config.home.file.".config/theme/shell.json".text = builtins.toJSON {
    island = config.my.shell.island.enable;
    barClear = config.my.shell.bar.clear.enable;
    islandGlass = config.my.shell.island.glass.enable;
    # A fact, not a wish: the `vpn` CLI and its units exist only where a host imports vpn.nix.
    vpn = osConfig.systemd.services ? "vpn-fai";
  };
}
