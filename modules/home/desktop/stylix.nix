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
    # Its HM module would set nixpkgs.overlays, which clashes with useGlobalPkgs and is an eval
    # warning (the CI aborts on warnings). Imported through NixOS it switches this off by itself.
    overlays.enable = false;
    autoEnable = true; # every app Stylix knows gets the palette; the exceptions are listed below
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

    # OFF, each for a reason. Everything else Stylix has a target for follows the palette by default.
    targets = {
      # Themed by this repo from the same palette, with keys base16 has no slot for.
      hyprland.enable = false; # hyprland.lua is written by hand, outside home-manager
      hyprlock.enable = false; # lockscreen.nix
      hyprpaper.enable = false; # wallpaper.nix owns hyprpaper.conf (random photo per monitor)
      qt.enable = false; # Kvantum, recolored from the palette (theme.nix)
      kde.enable = false; # it would apply a Plasma look-and-feel; there is no Plasma here
      gnome.enable = false; # no GNOME session; theme.nix owns the dconf interface keys (fonts, cursor)
      vicinae.enable = false; # desktop/vicinae: its theme needs border, which base16 lacks
      zen-browser.enable = false; # wrapped by hand, its theme measured in the lab (apps/zen/theme.nix)
      vscode.enable = false; # settings.json is versioned in the repo (rule 14)
      # An official per-app theme beats a generic base16 one: base16 has no bright ANSI slots, so
      # Stylix painted kitty's color8 #292e42 (autosuggestions near invisible) and every bright
      # color the same as its normal one. Measured 13/10/2026.
      # A base16 scheme (my.theme.name = "base16:...") has no official theme, so Stylix takes over.
      kitty.enable = !config.my.theme.curated; # kitty-themes' official scheme (shell/kitty.nix)
      kitty.opacity.enable = false; # kitty.nix keeps its own opacity and font either way
      kitty.fonts.enable = false;
      bat.enable = !config.my.theme.curated; # folke's own tmTheme, which delta reuses (shell/cli.nix)
      spicetify.enable = false; # it swaps the text theme for a colors-only one (apps/spotify.nix)
      btop.enable = false; # btop rewrites btop.conf, so an activation sets its theme (rule 14)
      # Not installed here: these targets write their theme files whether the app exists or not.
      blender.enable = false;
      forge.enable = false; # a GNOME Shell extension
      vencord.enable = false; # Discord runs without Vencord
      sxiv.enable = false; # an image viewer; Gwenview is the one here
      xresources.enable = false; # only old X11 apps read ~/.Xresources, and xterm was the last one
      gtk.flatpakSupport.enable = false; # no Flatpak here, so its override file would be dead
      # Colors only: mangohud.nix keeps its own transparency and font size.
      mangohud.opacity.enable = false;
      mangohud.fonts.enable = false;
      # Fonts are decision 0002's: fonts.nix owns the packages and fontconfig's defaults.
      font-packages.enable = false;
      fontconfig.enable = false;
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
