# SPOTIFY, themed by spicetify. `spicedSpotify` is the SSOT the autostart panel reads (rule 11).
# Why --no-zygote survives the patch and why `wayland` stays unset: docs/notes/apps/spotify.md
{
  config,
  inputs,
  pkgs,
  ...
}:

let
  # The theme and extension set, bound once because the theme below is its only consumer.
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  p = config.my.theme.palette; # the single source (modules/home/desktop/palette.nix)
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.default ];

  programs.spicetify = {
    enable = true; # it puts `spicedSpotify` in home.packages, so packages.nix must NOT list spotify
    # MY package, not the module's default: the overlay bakes --no-zygote into it (flake/overlays.nix), and
    # the builder only overrides postInstall, so postFixup carries the flag through.
    spotifyPackage = pkgs.unstable.spotify;
    spicetifyPackage = pkgs.unstable.spicetify-cli; # the SAME channel as the Spotify above
    theme = spicePkgs.themes.text; # the TUI-like theme, the one that was already used on Arch
    # The text theme's own keys, fed from the palette so Spotify follows my.theme.name. Under
    # tokyo-night it is the theme's TokyoNight scheme, green accent included; Stylix's spicetify
    # target is off because it swaps the whole theme for a colors-only one.
    colorScheme = "custom";
    customColorScheme = {
      accent = p.green;
      accent-active = p.green;
      accent-inactive = p.bg;
      banner = p.green;
      border-active = p.green;
      border-inactive = p.surface;
      header = p.dim;
      highlight = p.surface;
      main = p.bg;
      main-elevated = p.surface; # spicetify fills these two with #242424 and #2a2a2a otherwise
      highlight-elevated = p.track;
      notification = p.accent;
      notification-error = p.red;
      subtext = p.dim;
      text = p.subtext;
    };
  };
}
