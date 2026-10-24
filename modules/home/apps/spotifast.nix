# Spotifast: a native Spotify client (~200 MB instead of CEF), its colors fed from the palette.
# Why a COPY and not a symlink, and the one-time theme pick: docs/notes/apps/spotifast.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  p = lib.mapAttrs (_: v: "#${v}") config.my.theme.palette; # the single source (modules/home/desktop/palette.nix)

  # The app's palette format, mapped like the spicetify text scheme it replaces (green accent).
  # A fixed name, so the pick in settings.json survives a my.theme.name switch.
  theme = pkgs.writeText "spotifast-theme.json" (
    builtins.toJSON {
      base = "dark"; # the same polarity Stylix gets (modules/home/desktop/stylix.nix)
      colors = {
        inherit (p)
          surface
          text
          dim
          shadow
          ;
        window = p.bg;
        panel = p.bg;
        surface_hover = p.track;
        surface_active = p.border;
        outline = p.track;
        secondary = p.subtext;
        accent = p.green;
        accent_hover = p.teal;
        on_accent = p.bg;
        danger = p.red;
        warning = p.yellow;
      };
    }
  );
in
{
  home.packages = [ pkgs.spotifast ]; # the vendored release binary, pkgs/spotifast

  # A REAL file: the app skips symlinks in its themes folder, so home.file cannot own it.
  home.activation.spotifastTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run install -Dm644 ${theme} "''${XDG_CONFIG_HOME:-$HOME/.config}/spotifast/themes/dotfiles.json"
  '';
}
