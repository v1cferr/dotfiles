# The part of my home that only THIS laptop has: with no lock of its own, "lock" means the greeter.
# Why the session lock stayed on the desk: docs/decisions/0018-a-shared-laptop.md
{ ... }:

{
  home-manager.users.v1cferr = {
    imports = [
      ../../modules/home/desktop/greeter-switch.nix # `session-lock` hands the screen to GDM's greeter
    ];
  };
}
