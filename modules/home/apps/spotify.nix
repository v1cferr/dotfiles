# SPOTIFY, themed by spicetify. `spicedSpotify` is the SSOT the autostart panel reads (rule 11).
# Why --no-zygote survives the patch and why `wayland` stays unset: docs/notes/apps/spotify.md
{
  inputs,
  pkgs,
  ...
}:

let
  # The theme and extension set, bound once because the theme below is its only consumer.
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.default ];

  programs.spicetify = {
    enable = true; # it puts `spicedSpotify` in home.packages, so packages.nix must NOT list spotify
    # MY package, not the module's default: the overlay bakes --no-zygote into it (flake.nix), and
    # the builder only overrides postInstall, so postFixup carries the flag through.
    spotifyPackage = pkgs.unstable.spotify;
    spicetifyPackage = pkgs.unstable.spicetify-cli; # the SAME channel as the Spotify above
    theme = spicePkgs.themes.text; # the TUI-like theme, the one that was already used on Arch
    colorScheme = "TokyoNight"; # CHECKED at build time by the builder, so a typo fails loudly
  };
}
