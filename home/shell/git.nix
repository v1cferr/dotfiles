# The git CONFIG (~/.gitconfig), declared. The `git` binary comes from system/ (systemPackages).
# Here it is only the identity/preferences, plus gh, which is git's credential helper below.
{ config, lib, ... }:

{
  # gh lives HERE and not in packages.nix, because this module already depends on it: it is the
  # credential helper below and the token source above. `programs.gh` installs it (rule 4).
  programs.gh = {
    enable = true;
    # `git_protocol` is NOT declared: https is gh's own default, so setting it would be dead
    # config (rule 16). The only real content of the Arch config.yml was this one alias.
    settings.aliases.co = "pr checkout";
  };

  # The github MCP reads the token ONLY from this env var; it reuses gh's, instead of a new PAT.
  # The name does not hijack `gh auth`, which reads GH_TOKEN/GITHUB_TOKEN.
  programs.zsh.initContent = lib.mkOrder 1000 ''
    export GITHUB_PERSONAL_ACCESS_TOKEN="$(${config.programs.gh.package}/bin/gh auth token 2>/dev/null || true)"
  '';

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Victor Ferreira";
        email = "dev.victorferreira@gmail.com";
      };
      # NO `credential.helper` here anymore: `programs.gh.gitCredentialHelper` owns it (rule 14),
      # and it writes the ABSOLUTE store path instead of the `!gh` that needed gh on the PATH.
      # `git pull` rebases the local commits on top of the remote (a linear history; it ends the
      # "divergent branches" prompt). A personal single-author repo means rebase is clean.
      pull.rebase = true;
    };
  };
}
