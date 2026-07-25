# Meus serviços/timers do usuário (systemd --user).
{ ... }:

{
  imports = [
    ./cs2-saves-backup.nix # timer que espelha saves do CS2 (Bottles) p/ pasta do restic
  ];
}
