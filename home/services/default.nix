# My user services/timers (systemd --user).
{ ... }:

{
  imports = [
    ./cs2-saves-backup.nix # the timer that mirrors the CS2 saves (Bottles) into restic's folder
    ./claude-discord-rpc.nix # the daemon plus config of the Discord Rich Presence for Claude Code
    ./fai-workstation-mount.nix # ~/FAI-workstation = SFTP to the FAI workstation (rclone plus cache), under the VPN
    ./drive-mount.nix # ~/Drive = the Google Drive's root mounted (rclone mount), to browse in Dolphin
    ./arch-legacy-mount.nix # /mnt/arch-antigo = the old Arch archive mounted always (a restic mount)
    ./disk-hygiene.nix # the free space alarm (it notifies with the biggest consumers) plus an expiring trash
    ./razer-dpi.nix # the OSD for the Razer mouse's onboard DPI button (it polls hidraw)
    ./vm-boot-drill.nix # the weekly drill: it rebuilds the VM boot test and only speaks on failure
  ];
}
