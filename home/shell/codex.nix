# CODEX (OpenAI's CLI): the package plus config.toml as a mirror versioned in the repo.
# Why the config is not generated into the store: docs/notes/apps/codex.md
{
  config,
  osConfig,
  pkgs,
  ...
}:

let
  # The CLONED repo, from its SSOT programs.nh.flake (rule 11): the flake itself is in the store.
  repo = "${osConfig.programs.nh.flake}/home/shell/codex";
in
{
  programs.codex = {
    enable = true;
    # ./pkgs/codex, the OFFICIAL release binary: even unstable lags upstream by a release.
    package = pkgs.codex;
    # `settings` stays EMPTY on purpose: it generates a STORE file, and Codex PERSISTS into
    # config.toml at runtime (/model, /theme, approvals). The link below owns it instead.
  };

  # Same contract as Claude Code's settings.json: the app rewrites the file, so Nix owns only the
  # LINK and every adjustment lands as a git diff instead of invisible drift (rules 14 and 16).
  home.file.".codex/config.toml".source = config.lib.file.mkOutOfStoreSymlink "${repo}/config.toml";
}
