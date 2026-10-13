# ZapFast: a native WhatsApp client linked as a companion device (~200 MB instead of a browser tab).
# Unofficial, so it carries a ban risk; the trade-off and the fallback: docs/notes/apps/zapfast.md
{ pkgs, inputs, ... }:

let
  inherit (pkgs) removeReferencesTo stdenv;
  # The cc the flake builds with: it follows nixpkgs-unstable, so it is the hoisted unstable one.
  buildCc = pkgs.unstable.stdenv.cc;

  zapfast = inputs.zapfast.packages.${stdenv.hostPlatform.system}.zapfast.overrideAttrs (old: {
    # Upstream CI runs the suite; here it only added ~15 min of LTO build to every bump.
    doCheck = false;
    # The binary embeds the build's cc path as a string, which dragged gcc (+280 MiB) into the closure.
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ removeReferencesTo ];
    postFixup = (old.postFixup or "") + ''
      find $out/bin -type f -exec remove-references-to -t ${buildCc} {} +
    '';
    disallowedReferences = [ buildCc ];
  });
in
{
  home.packages = [ zapfast ];
}
