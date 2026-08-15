# THE COLOR PALETTE = the theme's SINGLE SOURCE (SSOT). Switching themes means changing
# `my.theme.name` (1 line) and rebuilding. Each preset carries the exact OFFICIAL hexes of its
# palette. The Nix consumers (rofi/lockscreen/flameshot) read `config.my.theme.palette.<color>`;
# the hot-reload ones (Quickshell/Hyprland) read the data files generated below (Nix cannot write
# inside the symlinked quickshell/hypr trees).
{
  config,
  lib,
  osConfig,
  ...
}:

let
  cfg = config.my.theme;

  # The presets: hexes WITHOUT '#', 6 digits (each consumer formats them as it needs).
  palettes = {
    # Tokyo Night (the Night variant), github.com/folke/tokyonight.nvim
    tokyo-night = {
      bg = "1a1b26"; # the base background
      surface = "1f2335"; # elevated (cards/popovers)
      track = "292e42"; # a track or a subtle highlight
      border = "414868"; # borders (terminal_black)
      text = "c0caf5"; # primary text (fg)
      subtext = "a9b1d6"; # secondary text (fg_dark)
      dim = "565f89"; # faded text (comment)
      accent = "7aa2f7"; # the accent color (= blue)
      blue = "7aa2f7";
      cyan = "7dcfff";
      sky = "89ddff"; # blue5
      teal = "73daca"; # green1
      green = "9ece6a";
      yellow = "e0af68";
      orange = "ff9e64";
      red = "f7768e";
      magenta = "bb9af7";
      purple = "9d7cd8";
      pink = "ff007c"; # magenta2
      shadow = "0f0f0f"; # the windows' shadow
    };
    # Catppuccin Mocha, catppuccin.com/palette (the 2nd preset, to demonstrate the switch).
    catppuccin-mocha = {
      bg = "1e1e2e"; # base
      surface = "313244"; # surface0
      track = "45475a"; # surface1
      border = "585b70"; # surface2
      text = "cdd6f4";
      subtext = "a6adc8"; # subtext0
      dim = "6c7086"; # overlay0
      accent = "89b4fa"; # blue
      blue = "89b4fa";
      cyan = "74c7ec"; # sapphire
      sky = "89dceb";
      teal = "94e2d5";
      green = "a6e3a1";
      yellow = "f9e2af";
      orange = "fab387"; # peach
      red = "f38ba8";
      magenta = "cba6f7"; # mauve
      purple = "cba6f7"; # mauve (Mocha does not separate purple)
      pink = "f5c2e7";
      shadow = "11111b"; # crust
    };
    # Gruvbox Dark, github.com/morhetz/gruvbox (a warm palette; great for testing the switch).
    gruvbox-dark = {
      bg = "282828"; # bg0
      surface = "3c3836"; # bg1
      track = "504945"; # bg2
      border = "665c54"; # bg3
      text = "ebdbb2"; # fg1
      subtext = "d5c4a1"; # fg2
      dim = "928374"; # gray
      accent = "fe8019"; # orange (Gruvbox's iconic accent)
      blue = "83a598";
      cyan = "8ec07c"; # aqua
      sky = "83a598";
      teal = "8ec07c";
      green = "b8bb26";
      yellow = "fabd2f";
      orange = "fe8019";
      red = "fb4934";
      magenta = "d3869b";
      purple = "b16286";
      pink = "d3869b";
      shadow = "1d2021"; # bg0_hard
    };
  };

  p = palettes.${cfg.name};
in
{
  options.my.theme = {
    name = lib.mkOption {
      type = lib.types.enum (lib.attrNames palettes);
      default = "tokyo-night";
      description = "The active theme (the single source of colors). Changing it here recolors the whole desktop.";
    };
    palette = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      internal = true;
      description = "The active theme's resolved palette (hexes without '#'). Read by the modules.";
    };
    # The ICON theme: it is theming, but it does NOT derive from the color preset, since
    # Win11-dark is the Windows 11 look and holds under any palette. The PACKAGE lives in
    # theme.nix (gtk.iconTheme.package), so switching means this line plus the package over
    # there. The NAME has to match the directory install.sh generates (`-n Win11` plus the
    # `-dark` variant), otherwise the theme silently falls back.
    iconTheme = lib.mkOption {
      type = lib.types.str;
      default = "Win11-dark";
      description = "The icon theme (SSOT). Read by theme.nix (dconf/GTK/kdeglobals) and by the rofi themes.";
    };
    # The cursor: the same reasoning. The package (bibata-cursors) lives in theme.nix.
    cursor = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "Bibata-Modern-Ice";
        description = "The cursor theme (SSOT). Read by theme.nix (dconf) and by Hyprland through hypr-colors.lua.";
      };
      size = lib.mkOption {
        type = lib.types.int;
        default = 24;
        description = "The cursor size in px (SSOT); it is global here, not per context.";
      };
    };
  };
  # The UI FONT does not live here: it is `my.fonts.ui`, in system/hardware/fonts.nix, next to
  # the package (rule 4). This module handles the rest of the theme. Consumers read it through
  # osConfig.

  config = {
    my.theme.palette = p;

    # Data for Quickshell: Theme.qml reads it through FileView plus JsonAdapter (colors with
    # '#'). uiFont goes along, since the .qml is a hot-reload symlink and Nix does not write
    # inside it, so this JSON is the only path to Quickshell (the file name is historical).
    home.file.".config/theme/quickshell-colors.json".text = builtins.toJSON (
      lib.mapAttrs (_: v: "#${v}") p // { uiFont = osConfig.my.fonts.ui; }
    );

    # Data for Hyprland: appearance.lua and environment.lua dofile it and use the table (hexes
    # without '#'). The cursor and its size go along, for the same reason as the JSON above: the
    # Lua is a hot-reload symlink and Nix does not interpolate inside it (the file name is
    # historical).
    home.file.".config/theme/hypr-colors.lua".text =
      "-- Generated by Nix (my.theme). Do NOT edit by hand; the source is home/desktop/palette.nix.\n"
      + "return {\n"
      + lib.concatStrings (lib.mapAttrsToList (k: v: "  ${k} = \"${v}\",\n") p)
      + "  cursorTheme = \"${cfg.cursor.name}\",\n"
      + "  cursorSize = \"${toString cfg.cursor.size}\",\n"
      + "}\n";
  };
}
