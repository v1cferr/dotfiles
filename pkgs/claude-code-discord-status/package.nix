# claude-code-discord-status: Discord Rich Presence for Claude Code, not in nixpkgs.
# Bump = new version plus BOTH hashes (nurl for the src, prefetch-npm-deps for the deps).
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
