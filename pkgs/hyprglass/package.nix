# HyprGlass: the Liquid Glass plugin for Hyprland, built against the EXACT compositor it loads into
# (the caller passes it). Why it is pinned and how it is loaded: docs/notes/desktop/hyprglass.md
{
  lib,
  hyprlandPlugins,
  hyprland,
  fetchFromGitHub,
  wayland-scanner,
}:

hyprlandPlugins.mkHyprlandPlugin {
  pluginName = "hyprglass";
  version = "0.10.0";
  inherit hyprland;

  # v0.10.0 is the release upstream's hyprpm.toml pins to Hyprland 0.56.2 (commit efb50993).
  src = fetchFromGitHub {
    owner = "hyprnux";
    repo = "hyprglass";
    rev = "84c1a5ab217101a317d4edaab7fba2efcc1bf346";
    hash = "sha256-60nDpYUgPXue7iSWHb05goz95j0cNmBYAyhlpviu7K4=";
  };

  nativeBuildInputs = [ wayland-scanner ];

  # The Makefile asks git for the version, and the source has no .git: `hyprctl plugin list` shows this.
  makeFlags = [ "HYPRGLASS_VERSION=0.10.0" ];

  installPhase = ''
    runHook preInstall
    install -Dm755 hyprglass.so $out/lib/libhyprglass.so
    runHook postInstall
  '';

  meta = {
    description = "Liquid Glass inspired window and layer effect for Hyprland";
    homepage = "https://github.com/hyprnux/hyprglass";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
