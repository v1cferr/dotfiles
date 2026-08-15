# ═══════════════════════════════════════════════════════════════════════════
# THE MODERN CLI: a terminal toolkit (Rust rewrites) plus the zsh integration.
#
# It lives in home/ ON PURPOSE: these are the USER's tools, and the programs.* modules already
# write the zsh integration (keybinds, hooks, completions) in a versioned way, which beats hooks
# by hand. (system/ remains the owner of the system level.)
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, lib, ... }:

{
  programs.eza.enable = true; # a modern ls (icons plus git); the aliases are right below
  programs.eza.git = true; # a git status column in the listing
  programs.bat.enable = true; # cat with syntax highlighting plus paging
  # delta: the "bat of git diff". Syntax highlighting, line numbers and PER FILE navigation inside
  # the pager, in `git diff`/`show`/`log -p`/`blame`. It is the highest-impact one on this list for
  # the same reason as bat: reading a diff is the most repeated operation here, and git's raw diff
  # is monochrome.
  #
  # difftastic was passed over (a STRUCTURAL diff, comparing the syntax tree instead of lines): it
  # solves another problem, "I renamed/reindented and the diff exploded", and the community itself
  # uses both together, delta as the day-to-day pager. It comes in later if the need shows up;
  # installing both now would be choosing without having the problem.
  programs.delta = {
    enable = true;
    enableGitIntegration = true; # NOT the default: without this delta sits installed and idle
    options = {
      navigate = true; # `n`/`N` jumps between files inside the pager (a big diff becomes navigable)
      line-numbers = true; # a line column on both sides, so counting by hand inside the hunk goes away
      # side-by-side is OFF on purpose: the .nix files here have a comment block per config
      # (rule 2) and lines of ~90 columns. At 1920x1080, two columns break everything and the diff
      # comes out WORSE than the single-column one. When you want it, per invocation:
      # `git diff --side-by-side` (delta accepts its own flags through git).
    };
  };
  # zoxide: `cd partial-name` jumps to the most used folder (it learns as you navigate); a normal
  # `cd` (path/../-) still works; `cdi` is an fzf picker. The end of typing the whole dir.
  programs.zoxide.enable = true; # it installs the binary (the zsh init goes at the end, below)
  # HM injects the zoxide-zsh init early (mkOrder 851), which trips the doctor's false positive
  # ("initialize at the end"). The correct fix (home-manager#9349): turn the automatic integration
  # off and reinject the init at the END of .zshrc (mkOrder 2000, after every mkAfter), so the
  # doctor is genuinely satisfied, with nothing silenced. --cmd cd makes `cd` become zoxide.
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
  # direnv: entering a folder with an .envrc activates the environment (`use flake`, say).
  # nix-direnv is the cache that makes the per-folder `nix develop` fast (essential for dev/AI).
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Binaries with no dedicated programs.* module (just the package in the user's profile).
  # All chosen for a REAL GAP, not from an "awesome" list: each one below is a tool that was
  # missing during a concrete debugging session on this machine.
  home.packages = with pkgs; [
    fd # a modern find (fast, it respects .gitignore), `fd nix`
    ripgrep # a modern grep (rg): ultra-fast recursive text search
    # dust: `du` as a tree, sorted by size and with a bar. It complements filelight (a GUI that
    # shows FOLDERS) and czkawka (which finds what is DISPOSABLE) in a third case: "what is taking
    # up space HERE", over SSH, with no graphical session. On this machine that matters: the
    # partition is shared with games and media (506 GiB measured against 58 GiB of store).
    dust
    # doggo: a modern `dig` (colored, readable output, it speaks DoH/DoT). It comes in because its
    # absence HURT: on 03/08, debugging the dynamic DNS and the external SSH, `dig` did not exist
    # on this machine and the query had to go out through `curl` against Cloudflare's DoH API.
    # `dnsutils` comes along: the classic `dig` is the lingua franca of every network doc and
    # script, and I do not want to translate somebody else's troubleshooting command in a pinch.
    doggo
    dnsutils
    # procs: a modern `ps`, colored, with a tree, and searching by name with no pipe into grep.
    # I spent a whole day in `pgrep -a` / `ps -o` hunting Hyprland, hyprlock and sunshine; that is
    # exactly its use case.
    procs
    # hyperfine: a command-line benchmark with statistics (mean, deviation, warmup). It comes in
    # because it matches this repo's culture: nearly every comment here starts with "MEASURED
    # on…". It was what was missing to measure CORRECTLY instead of timing a single run: `time`
    # measures one sample, hyperfine measures the distribution.
    hyperfine
  ];

  # The toolkit's aliases (the shell/system ones stay in zsh.nix):
  programs.zsh.shellAliases = {
    ls = "eza --icons --group-directories-first"; # ls with icons, folders first
    ll = "eza -lah --icons --git --group-directories-first"; # detailed plus hidden plus git
    la = "eza -a --icons --group-directories-first"; # everything (except . and ..)
    lt = "eza --tree --icons --level=2"; # a tree (2 levels)
    cat = "bat --paging=never"; # cat with highlighting (it acts like cat when redirected)
  };
}
