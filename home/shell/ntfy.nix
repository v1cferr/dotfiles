# `notify` on the PATH; the script is `pkgs/notify.nix`, since sshd's PAM hook is a second
# consumer a home-manager package cannot reach (rule 4): docs/notes/repo/shell.md
{ pkgs, ... }:

{
  home.packages = [ pkgs.notify ];
}
