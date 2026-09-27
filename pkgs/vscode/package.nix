# VS Code: unstable's RECIPE with the SRC swapped for Microsoft's tarball, always the latest stable.
# Why the recipe comes from unstable and the src does not: docs/notes/repo/flake.md
{
  lib,
  fetchurl,
  callPackage,
  vscode,
}:

let
  # version, url and hash: the ONLY file the bump writes. The hash is the one the API PUBLISHES.
  source = lib.importJSON ./source.json;
in
vscode.overrideAttrs (old: {
  inherit (source) version;

  # nixpkgs' own name for it, so the unpack lands where its recipe expects.
  src = fetchurl {
    name = "VSCode_${source.version}_linux-x64.tar.gz";
    inherit (source) url hash;
  };

  # OURS replaces nixpkgs' update-vscode.sh, which edits nixpkgs and not this file.
  passthru = old.passthru // {
    updateScript = callPackage ./bump.nix { };
  };
})
