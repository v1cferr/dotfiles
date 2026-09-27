# CODEX (OpenAI's CLI): the package plus config.toml as a mirror versioned in the repo.
# Why the config is not generated into the store: docs/notes/apps/codex.md
{ config, pkgs, ... }:

let
  # The CLONED repo path: it cannot be derived, since the flake is copied into the store.
  repo = "${config.home.homeDirectory}/Projects/GitHub/v1cferr/dotfiles/home/shell/codex";
in
{
  programs.codex = {
    enable = true;
    # ./pkgs/codex.nix, the OFFICIAL release binary: even unstable lags upstream by a release.
    package = pkgs.codex;
    # `settings` stays EMPTY on purpose: it generates a STORE file, and Codex PERSISTS into
    # config.toml at runtime (/model, /theme, approvals). The link below owns it instead.
  };

  # Same contract as Claude Code's settings.json: the app rewrites the file, so Nix owns only the
  # LINK and every adjustment lands as a git diff instead of invisible drift (rules 14 and 16).
  home.file.".codex/config.toml".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config.toml";
}
