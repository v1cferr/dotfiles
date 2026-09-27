# The zsh config (~/.zshrc). The LOGIN shell is set in system/core/users.nix.
# Why the aliases are composed and why the flake path is explicit: docs/notes/repo/shell.md
{
  osConfig,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs) vendored-bump;

  # SSOT of the repo path (rule 11): programs.nh.flake, read here through osConfig.
  flake = osConfig.programs.nh.flake;

  # Composed, never written twice: `upgrade` IS `update && rebuild` by definition. The bumps go
  # BEFORE the lock (vscode's raises a versioned input), and `&&` stops a half-edited repo.
  update = "${lib.getExe vendored-bump} ${flake} && nix flake update --flake ${flake} && vscode-extensions-dump ${flake}";
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true; # completes commands and paths with Tab (compinit)
    autosuggestion.enable = true; # suggests from history in gray
    syntaxHighlighting.enable = true; # green = it exists, red = it does not
    autocd = true; # typing just the path does the cd

    history = {
      size = 50000; # lines kept in memory during the session
      save = 50000; # lines written to the history file
      ignoreDups = true; # no consecutive duplicate
      ignoreAllDups = true; # on a repeat, the older occurrence goes
      ignoreSpace = true; # a command starting with a space stays out
      expireDuplicatesFirst = true; # pruning kills a duplicate before a unique command
      share = true; # shared between tabs in real time
    };

    # Functions, not aliases: they take arguments, so `rebuild -vv` or `upgrade -vvv` reach nh.
    siteFunctions = {
      # The `-i 0` is what makes this work over SSH: hyprctl otherwise demands
      # HYPRLAND_INSTANCE_SIGNATURE, which only exists inside the graphical session.
      rebuild = ''nh os switch "$@" ${flake} && { hyprctl -i 0 reload || true; }'';
      inherit update; # bumps the lock plus the vendored versions
      # As the USER first (it holds the SSH key for private inputs), then root.
      upgrade = ''update && rebuild "$@"'';
    };

    shellAliases = {
      # CAREFUL: `-d` deletes ALL old generations, so there is no rollback afterwards.
      gc = "sudo nix-collect-garbage -d";

      # Wallpaper: 1 is the main panel and 2 the standing one; wppin keeps what is on screen at boot.
      wp = "wallpaper-shuffle both";
      wppin = "wallpaper-shuffle pin";
      wp1 = "wallpaper-shuffle 1";
      wp2 = "wallpaper-shuffle 2";

      # ls/ll/la/lt (eza) and cat (bat) live in cli.nix, next to the toolkit.
      ".." = "cd ..";
      "..." = "cd ../..";
    };
  };

  # The terminal editor for git, `systemctl edit` and visudo. Set ONCE here and NOT also as
  # git's core.editor, which would be a second owner of the same decision (rule 14).
  home.sessionVariables.EDITOR = "vim";

  # 1500 and not the tail: mkOrder 2000 belongs to zoxide's init (see cli.nix).
  # Only the TWO bindings that were measured missing came back from the Arch shell; Home, End,
  # Delete and the arrows are already bound, so porting those would be dead config (rule 16).
  programs.zsh.initContent = lib.mkOrder 1500 ''
    bindkey "^[[1;5C" forward-word   # Ctrl+Right: jump a word forward
    bindkey "^[[1;5D" backward-word  # Ctrl+Left: jump a word back

    # Esc Esc prefixes (or strips) sudo on the line being typed. With an EMPTY line it pulls the
    # previous command first, which is the case it actually gets used for.
    sudo-command-line() {
      [[ -z $BUFFER ]] && zle up-history
      if [[ $BUFFER == sudo\ * ]]; then
        LBUFFER="''${LBUFFER#sudo }"
      else
        LBUFFER="sudo $LBUFFER"
      fi
    }
    zle -N sudo-command-line
    bindkey "\e\e" sudo-command-line
  '';
}
