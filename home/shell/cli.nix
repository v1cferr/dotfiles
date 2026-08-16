# The modern CLI toolkit. Each tool filled a REAL gap in a debugging session, not a list slot.
# Which gap, and why difftastic was passed over: docs/notes/repo/shell.md
{ pkgs, lib, ... }:

{
  programs.eza.enable = true; # a modern ls (icons plus git); the aliases are right below
  programs.eza.git = true; # a git status column in the listing
  programs.bat.enable = true; # cat with syntax highlighting plus paging
  # delta: the "bat of git diff". Reading a diff is the most repeated operation here.
  programs.delta = {
    enable = true;
    enableGitIntegration = true; # NOT the default: without this delta sits installed and idle
    options = {
      navigate = true; # `n`/`N` jumps between files inside the pager (a big diff becomes navigable)
      line-numbers = true; # a line column on both sides, so counting by hand inside the hunk goes away
      # side-by-side is OFF: at 1920x1080 two columns read worse than one here.
      # Per invocation it still works: `git diff --side-by-side`.
    };
  };
  # zoxide: `cd partial-name` jumps to the most used folder; `cdi` is an fzf picker.
  programs.zoxide.enable = true; # it installs the binary (the zsh init goes at the end, below)
  # Reinjected at the END (mkOrder 2000): HM's early init trips zoxide's doctor.
  programs.zoxide.enableZshIntegration = false;
  programs.zsh.initContent = lib.mkOrder 2000 ''
    eval "$(${pkgs.zoxide}/bin/zoxide init zsh --cmd cd)"
  '';
  programs.fzf.enable = true; # a fuzzy finder: Ctrl+R (history), Ctrl+T (file), Alt+C (cd)
  programs.yazi.enable = true; # a TUI file manager with previews (it uses bat; `y` cds on exit)
  programs.tealdeer = {
    enable = true; # `tldr <cmd>` gives practical examples (tldr in Rust)
    settings.updates.auto_update = true; # it downloads/updates the tldr cache on its own
  };
  # direnv plus nix-direnv: entering the repo enters its devShell, cached.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Binaries with no programs.* module of their own.
  home.packages = with pkgs; [
    fd # a modern find (fast, it respects .gitignore), `fd nix`
    ripgrep # a modern grep (rg): ultra-fast recursive text search
    # dust: "what is taking space HERE", over SSH, with no graphical session.
    dust
    # doggo plus dnsutils: on 03/08 `dig` did not exist here and the DDNS debug went out
    # through curl against a DoH API.
    doggo
    dnsutils
    # procs: a modern `ps`, after a whole day of pgrep hunting Hyprland and sunshine.
    procs
    # hyperfine: `time` measures one sample, this measures the distribution.
    hyperfine
  ];

  # The toolkit's aliases; the shell and system ones stay in zsh.nix.
  programs.zsh.shellAliases = {
    ls = "eza --icons --group-directories-first"; # ls with icons, folders first
    ll = "eza -lah --icons --git --group-directories-first"; # detailed plus hidden plus git
    la = "eza -a --icons --group-directories-first"; # everything (except . and ..)
    lt = "eza --tree --icons --level=2"; # a tree (2 levels)
    cat = "bat --paging=never"; # cat with highlighting (it acts like cat when redirected)
  };
}
