# ANTIGRAVITY IDE: unstable's RECIPE with the SRC swapped for Google's tarball, always the latest.
# Why the recipe comes from unstable and the src does not: docs/notes/apps/antigravity-ide.md
{
  lib,
  fetchurl,
  callPackage,
  antigravity-ide,
}:

let
  # version, url and hash: the ONLY file the bump writes. The hash is the one the API PUBLISHES.
  source = lib.importJSON ./source.json;
in
antigravity-ide.overrideAttrs (old: {
  inherit (source) version;

  # An explicit name: the url's basename carries a %20, which is no store path character.
  src = fetchurl {
    name = "antigravity-ide-${source.version}-linux-x64.tar.gz";
    inherit (source) url hash;
  };

  # OURS replaces nixpkgs' update.js, which edits nixpkgs and not this file.
  passthru = old.passthru // {
    updateScript = callPackage ./bump.nix { };
  };
})
