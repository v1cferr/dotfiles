# The git CONFIG (~/.gitconfig): identity, preferences and gh as the credential helper. The binary
# is modules/nixos/'s (systemPackages). No note: the settings below are the whole story.
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

  # `force` because the token export below runs gh on EVERY shell start, and gh writes a stub
  # config when the file is missing, so it wins the race against activation: notes/repo/packages.md
  xdg.configFile."gh/config.yml".force = true;

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
      # The rebase above stashes and restores a dirty working tree by itself, so editor churn
      # (the VS Code file nesting timestamp) stops refusing the pull with "unstaged changes".
      rebase.autoStash = true;
      # The defaults core Git developers override, kept by git only for backward compatibility:
      # https://blog.gitbutler.com/how-git-core-devs-configure-git
      rebase.autoSquash = true; # `fixup!` commits fold in by themselves
      rebase.updateRefs = true; # stacked branches follow the rebase
      init.defaultBranch = "main"; # Git 3.0's own default; until then it only silences the hint
      commit.verbose = true; # the diff sits under the message being written
      merge.conflictStyle = "zdiff3"; # conflicts also show the common base
      diff = {
        algorithm = "histogram"; # cleaner hunks than myers
        colorMoved = "plain"; # moved code reads apart from new code
        mnemonicPrefix = true; # i/ w/ c/ instead of a/ b/
        renames = true;
      };
      push = {
        autoSetupRemote = true; # no more --set-upstream on a new branch
        followTags = true;
      };
      fetch = {
        prune = true; # drop remote branches and tags deleted upstream
        pruneTags = true;
        all = true;
      };
      branch.sort = "-committerdate"; # most recent first
      tag.sort = "version:refname"; # v1.10 after v1.9
      column.ui = "auto";
      help.autocorrect = "prompt";
    };
  };
}
