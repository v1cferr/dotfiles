# tmux, for Claude sessions I can join live from the phone (Termius) while the PC stays attached.
# Why tmux and not zmx/Zellij/shpool, and the Termius side: docs/notes/apps/tmux.md
{ pkgs, ... }:

let
  inherit (pkgs) coreutils tmux writeShellApplication;

  # `ct [claude args]`: Claude inside a tmux session named after the folder, joined if it exists.
  claudeTmux = writeShellApplication {
    name = "ct";
    runtimeInputs = [
      coreutils
      tmux
    ];
    text = ''
      # Already inside tmux: nesting would put a status bar inside a status bar, so just run it.
      if [ -n "''${TMUX-}" ]; then
        exec claude "$@"
      fi
      # tmux refuses `.` and `:` in a session name, and folders like `v1cferr.dev` have them.
      name=$(basename "$PWD" | tr '.:' '__')
      exec tmux new-session -A -s "$name" claude "$@"
    '';
  };
in
{
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color"; # the module defaults to `screen`, which loses italics and colors
    escapeTime = 10; # tmux's own default; the module's 500 ms lags every Esc in Claude Code
    historyLimit = 50000; # a long Claude run outgrows the 2000-line default
    baseIndex = 1; # window 1 is the first key on the keyboard, not the last
    mouse = true; # a swipe in Termius scrolls and a tap picks a session (reasoned, see the note)
    focusEvents = true; # Claude Code redraws on focus, like it does outside tmux
    extraConfig = ''
      # Shift+Enter reaches Claude Code as a newline instead of a plain Enter that submits.
      set -s extended-keys on
      set -s extended-keys-format csi-u
      # kitty does truecolor and extended keys; tmux only uses what the terminal declares.
      set -as terminal-features ',xterm-kitty:RGB:extkeys'
    '';
  };

  home.packages = [ claudeTmux ];
}
