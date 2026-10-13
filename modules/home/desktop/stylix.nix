# STYLIX: it APPLIES my.theme.palette to the apps it has targets for. The palette stays the owner of
# the hexes, since the stock base16 Tokyo Night is not folke's: docs/decisions/0012-stylix-applies-the-palette.md
{
  config,
  osConfig,
  pkgs,
  inputs,
  ...
}:

let
  inherit (pkgs) nerd-fonts noto-fonts-color-emoji;

  p = config.my.theme.palette;

  # The UI is monospace by choice (decision 0002), so every Stylix family is the same one.
  ui = {
    package = nerd-fonts.jetbrains-mono;
    name = osConfig.my.fonts.ui;
  };
in
{
  imports = [ inputs.stylix.homeModules.stylix ];

  stylix = {
    enable = true;
    autoEnable = false; # opt-in while the targets are moved over one at a time
    polarity = "dark";

    # The palette mapped onto base16's slots. base16 has no room for sky, teal, purple, border or
    # shadow; the consumers that need those keep reading my.theme.palette directly.
    base16Scheme = {
      scheme = config.my.theme.name;
      author = "modules/home/desktop/palette.nix";
      base00 = p.bg;
      base01 = p.surface;
      base02 = p.track;
      base03 = p.dim;
      base04 = p.subtext;
      base05 = p.text;
      base06 = p.text;
      base07 = p.text;
      base08 = p.red;
      base09 = p.orange;
      base0A = p.yellow;
      base0B = p.green;
      base0C = p.cyan;
      base0D = p.accent;
      base0E = p.magenta;
      base0F = p.pink;
    };

    # The apps it themes, moved over one at a time while autoEnable is off.
    targets = {
      gtk.enable = true; # adw-gtk3 plus a gtk.css in the palette; Adwaita gray before
    };

    fonts = {
      monospace = ui;
      sansSerif = ui;
      serif = ui;
      emoji = {
        package = noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      # The sizes the apps already use: GTK at 11, kitty at 12.
      sizes = {
        applications = 11;
        desktop = 11;
        popups = 11;
        terminal = 12;
      };
    };
  };
}
