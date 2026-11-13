# HyprGlass: the Liquid Glass plugin for Hyprland, built against the EXACT compositor it loads into
# (the caller passes it). Why it is pinned and how it is loaded: docs/notes/desktop/hyprglass.md
{
  lib,
  hyprlandPlugins,
  hyprland,
  fetchFromGitHub,
  wayland-scanner,
}:

let
  # Upstream's hyprpm.toml `commit_pins`, declared: each Hyprland release builds one HyprGlass release.
  # An `update` that brings a new Hyprland fails HERE, by name, until its pair is added.
  pins = {
    "0.56.2" = {
      version = "0.10.0";
      rev = "84c1a5ab217101a317d4edaab7fba2efcc1bf346";
      hash = "sha256-60nDpYUgPXue7iSWHb05goz95j0cNmBYAyhlpviu7K4=";
    };
    "0.57.0" = {
      version = "1.1.0";
      rev = "85b8a8ed8431d7b6f1ef8dad8ae0470d8ea7f291";
      hash = "sha256-Jq47p3kJ3N/qw8E83lIewjg9hp7oJw9iIYzMT+YPXic=";
    };
    "0.57.1" = {
      version = "1.1.1";
      rev = "03a57c4451b4abee38feda2ffb725f55ecc0f2fd";
      hash = "sha256-cQmVmmdaITss2hO6aidKOtq6GtEe85fmgrPcrn1eIUg=";
    };
    "0.57.2" = {
      version = "1.1.1";
      rev = "03a57c4451b4abee38feda2ffb725f55ecc0f2fd";
      hash = "sha256-cQmVmmdaITss2hO6aidKOtq6GtEe85fmgrPcrn1eIUg=";
    };
  };
  pin =
    pins.${hyprland.version}
      or (throw "hyprglass: no release pinned for Hyprland ${hyprland.version}; add it from upstream's hyprpm.toml");
in
hyprlandPlugins.mkHyprlandPlugin {
  pluginName = "hyprglass";
  inherit (pin) version;
  inherit hyprland;

  src = fetchFromGitHub {
    owner = "hyprnux";
    repo = "hyprglass";
    inherit (pin) rev hash;
  };

  nativeBuildInputs = [ wayland-scanner ];

  # The Makefile asks git for the version, and the source has no .git: `hyprctl plugin list` shows this.
  makeFlags = [ "HYPRGLASS_VERSION=${pin.version}" ];

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
