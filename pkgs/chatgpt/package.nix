# ChatGPT: unstable's RECIPE with the SRC swapped for OpenAI's newest .deb, always the latest build.
# Why the channel is not enough on its own: docs/notes/apps/chatgpt.md
{
  lib,
  callPackage,
  chatgpt,
}:

let
  # version, url and hash: the ONLY file the bump writes. The hash is the one the apt repo PUBLISHES.
  source = lib.importJSON ./source.json;
in
chatgpt.overrideAttrs (old: {
  # nixpkgs reads version and src from passthru.source, so swapping that one attrset is enough.
  passthru = old.passthru // {
    source = {
      inherit (source) version;
      src = { inherit (source) url hash; };
    };
    # OURS replaces nixpkgs' update.sh, which edits nixpkgs and not this file.
    updateScript = callPackage ./bump.nix { };
  };
})
