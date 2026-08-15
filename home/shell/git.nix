# The git CONFIG (~/.gitconfig), declared. The `git` binary comes from system/ (systemPackages).
# Here it is only the identity/preferences.
{ pkgs, lib, ... }:

{
  # Claude Code's `github` plugin talks to the remote MCP (api.githubcopilot.com) and reads the
  # token ONLY from the GITHUB_PERSONAL_ACCESS_TOKEN env; without it the header comes out as an
  # empty `Bearer ` and the server answers HTTP 400. It reuses the token gh already keeps, instead
  # of generating a new PAT and leaving it in plain text. gh only reads GH_TOKEN/GITHUB_TOKEN, so
  # this name does NOT hijack `gh auth status/refresh`. `|| true` means a machine with gh not
  # logged in does not break.
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
