# CODEX (OpenAI's CLI): the package. Its declared config is Codex's SYSTEM layer, installed by
# modules/nixos/services/codex.nix; ~/.codex/config.toml is left to Codex: docs/notes/apps/codex.md
{ pkgs, ... }:

{
  programs.codex = {
    enable = true;
    # ./pkgs/codex, the OFFICIAL release binary: even unstable lags upstream by a release.
    package = pkgs.codex;
    # `settings` stays EMPTY on purpose: it would make ~/.codex/config.toml a read-only store
    # file, and Codex and the ChatGPT app PERSIST into it at runtime (/model, approvals, servers).
  };
}
