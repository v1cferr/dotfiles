# claude-code-discord-status — Discord Rich Presence pro Claude Code.
# NÃO está no nixpkgs → empacotado aqui e exposto via overlay (flake.nix), pra
# system/ e home/ referenciarem o MESMO build (`pkgs.claude-code-discord-status`).
#
# Fonte no GitHub (tem package-lock.json → buildNpmPackage). O `npm run build`
# (tsup) gera o dist/; `src/hooks/` e `dist/` entram no output via `files` do
# package.json. Bump de versão: trocar `version` + os DOIS hashes (src via
# `nurl`, deps via `nix run nixpkgs#prefetch-npm-deps -- package-lock.json`).
{ lib, buildNpmPackage, fetchFromGitHub }:

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
    description = "Discord Rich Presence pro Claude Code (daemon + hooks)";
    homepage = "https://github.com/BrunoJurkovic/claude-code-discord-status";
    license = lib.licenses.mit;
    mainProgram = "claude-presence";
  };
}
