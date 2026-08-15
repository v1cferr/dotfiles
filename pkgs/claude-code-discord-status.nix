# claude-code-discord-status: Discord Rich Presence for Claude Code.
# It is NOT in nixpkgs, so it is packaged here and exposed through the overlay (flake.nix), for
# system/ and home/ to reference the SAME build (`pkgs.claude-code-discord-status`).
#
# The source is on GitHub (it has a package-lock.json, hence buildNpmPackage). `npm run build`
# (tsup) generates the dist/; `src/hooks/` and `dist/` enter the output through package.json's
# `files`. To bump the version: change `version` plus BOTH hashes (the src through `nurl`, the
# deps through `nix run nixpkgs#prefetch-npm-deps -- package-lock.json`).
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "claude-code-discord-status";
  version = "2.0.1";

  src = fetchFromGitHub {
    owner = "BrunoJurkovic";
    repo = "claude-code-discord-status";
    tag = "v${version}";
    hash = "sha256-z8NK3qonxRuaLHVICZYHCTZMIPNk5Dm1SCEZSunTlXM=";
  };

  npmDepsHash = "sha256-al8Ruydl6txoarbguJhWR2aLgGMGrar0psK/qbWJ3Wc=";

  meta = {
    description = "Discord Rich Presence for Claude Code (daemon plus hooks)";
    homepage = "https://github.com/BrunoJurkovic/claude-code-discord-status";
    license = lib.licenses.mit;
    mainProgram = "claude-presence";
  };
}
