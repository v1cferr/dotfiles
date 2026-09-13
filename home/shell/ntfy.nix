# `notify` on the PATH. The script itself moved to `pkgs/notify.nix` the day sshd's PAM hook
# became a second consumer, and a home-manager package is out of a system module's reach (rule 4).
{ pkgs, ... }:

{
  home.packages = [ pkgs.notify ];
}
