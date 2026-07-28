# Meus serviços/timers do usuário (systemd --user).
{ ... }:

{
  imports = [
    ./cs2-saves-backup.nix # timer que espelha saves do CS2 (Bottles) p/ pasta do restic
    ./claude-discord-rpc.nix # daemon + config do Discord Rich Presence pro Claude Code
    ./fai-workstation-mount.nix # ~/FAI-workstation = SFTP da workstation FAI (rclone+cache), sob VPN
  ];
}
