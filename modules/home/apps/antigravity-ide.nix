# ANTIGRAVITY IDE: Google's agent-first editor, unstable's recipe on the official tarball.
# Why the src is ours and why nothing of its config is declared: docs/notes/apps/antigravity-ide.md
{ pkgs, ... }:

let
  inherit (pkgs.unstable) antigravity-ide;
in
{
  home.packages = [ antigravity-ide ];
}
