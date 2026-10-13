# THE PALETTE: the theme's SSOT. Switching = `my.theme.name` plus a rebuild. Nix consumers read
# the option; the hot-reload ones read the files below: docs/notes/desktop/theme.md
{
  config,
  lib,
  osConfig,
  pkgs,
  inputs,
  ...
}:

let
  inherit (pkgs) base16-schemes;

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

  # ANY base16 scheme, as `base16:<file>` from base16-schemes (ls its share/themes). The 20 keys are
  # DERIVED from the 16 slots, so the extras repeat a neighbor: sky and teal are the cyan, purple is
  # the magenta. The curated presets above keep their exact hexes; a stock scheme may not match the
  # official colors of the theme it is named after (decision 0012).
  base16Prefix = "base16:";
  curated = !(lib.hasPrefix base16Prefix cfg.name);
  fromBase16 =
    slug:
    let
      s =
        (inputs.stylix.inputs.base16.lib { inherit pkgs lib; }).mkSchemeAttrs
          "${base16-schemes}/share/themes/${slug}.yaml";
    in
    {
      bg = s.base00;
      surface = s.base01;
      track = s.base02;
      border = s.base03;
      text = s.base05;
      subtext = s.base04;
      dim = s.base03;
      accent = s.base0D;
      blue = s.base0D;
      cyan = s.base0C;
      sky = s.base0C;
      teal = s.base0C;
      green = s.base0B;
      yellow = s.base0A;
      orange = s.base09;
      red = s.base08;
      magenta = s.base0E;
      purple = s.base0E;
      pink = s.base0F;
      shadow = "000000";
    };

  p = if curated then palettes.${cfg.name} else fromBase16 (lib.removePrefix base16Prefix cfg.name);
in
{
  options.my.theme = {
    name = lib.mkOption {
      type = lib.types.either (lib.types.enum (lib.attrNames palettes)) (
        lib.types.strMatching "base16:[A-Za-z0-9_-]+"
      );
      default = "tokyo-night";
      description = "The active theme: a curated preset, or `base16:<scheme>` from base16-schemes. Changing it recolors the whole desktop.";
    };
    curated = lib.mkOption {
      type = lib.types.bool;
      readOnly = true;
      default = curated;
      description = "Whether the theme is a curated preset, so apps with an official per-preset theme (kitty, bat, btop) use it; a base16 scheme falls back to Stylix.";
    };
    slug = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = lib.replaceStrings [ ":" ] [ "-" ] cfg.name; # a base16 name has a colon
      description = "The theme name, safe in a file name. Names the Kvantum theme and the KDE color scheme.";
    };
    palette = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      internal = true;
      description = "The active theme's resolved palette (hexes without '#'). Read by the modules.";
    };
    # The icon theme and the cursor: theming, but they do NOT derive from the color preset. Their
    # PACKAGES live in theme.nix, and the NAME must match what install.sh generates.
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
  # The UI FONT is `my.fonts.ui`, in modules/nixos/desktop/fonts.nix, next to its package (rule 4).

  config = {
    my.theme.palette = p;

    # Data for Quickshell (Theme.qml reads it through FileView plus JsonAdapter). uiFont rides
    # along because this JSON is the ONLY path into a hot-reload tree; the name is historical.
    home.file.".config/theme/quickshell-colors.json".text = builtins.toJSON (
      lib.mapAttrs (_: v: "#${v}") p // { uiFont = osConfig.my.fonts.ui; }
    );

    # Data for Hyprland (appearance.lua and environment.lua dofile it). The cursor and the Qt pair
    # ride along for the same reason as the JSON above; the file name is historical.
    home.file.".config/theme/hypr-colors.lua".text =
      "-- Generated by Nix (my.theme). Do NOT edit by hand; the source is modules/home/desktop/palette.nix.\n"
      + "return {\n"
      + lib.concatStrings (lib.mapAttrsToList (k: v: "  ${k} = \"${v}\",\n") p)
      + "  cursorTheme = \"${cfg.cursor.name}\",\n"
      + "  cursorSize = \"${toString cfg.cursor.size}\",\n"
      # The Qt pair, owned by qt.* in theme.nix: Hyprland's children must get the same values.
      + "  qtPlatformTheme = \"${config.home.sessionVariables.QT_QPA_PLATFORMTHEME}\",\n"
      + "  qtStyle = \"${config.home.sessionVariables.QT_STYLE_OVERRIDE}\",\n"
      + "}\n";
  };
}
