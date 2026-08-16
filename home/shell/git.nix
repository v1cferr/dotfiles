# The git CONFIG (~/.gitconfig), declared. The `git` binary comes from system/ (systemPackages).
# Here it is only the identity/preferences.
{ pkgs, lib, ... }:

{
  # The github MCP reads the token ONLY from this env var; it reuses gh's, instead of a new PAT.
  # The name does not hijack `gh auth`, which reads GH_TOKEN/GITHUB_TOKEN.
  programs.zsh.initContent = lib.mkOrder 1000 ''
    export GITHUB_PERSONAL_ACCESS_TOKEN="$(${pkgs.gh}/bin/gh auth token 2>/dev/null || true)"
  '';

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Victor Ferreira";
        email = "dev.victorferreira@gmail.com";
      };
      # GitHub over HTTPS uses gh's token (the GitHub CLI) as the credential helper, so
      # `git push/pull` work with no SSH and with no token written in plain text.
      credential."https://github.com".helper = "!gh auth git-credential";
      # `git pull` rebases the local commits on top of the remote (a linear history; it ends the
      # "divergent branches" prompt). A personal single-author repo means rebase is clean.
      pull.rebase = true;
    };
  };
}
