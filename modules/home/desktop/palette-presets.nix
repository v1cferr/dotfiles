# THE PRESETS, as plain data: read by palette.nix (the desktop) AND by the docs site, which is
# built outside home-manager. Why a file of its own: docs/notes/desktop/theme.md
{
  # The preset the desktop runs unless a host sets my.theme.name, and the one the site wears.
  default = "tokyo-night";

  presets = {
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
}
