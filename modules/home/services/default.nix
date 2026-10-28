# My user services/timers (systemd --user).
{ ... }:

{
  imports = [
    ./cs2-saves-backup.nix # the timer that mirrors the CS2 saves out of the Bottles prefix
    ./claude-discord-rpc.nix # the daemon plus config of the Discord Rich Presence for Claude Code
    ./fai-workstation-mount.nix # ~/FAI-workstation = SFTP to the FAI workstation (rclone plus cache), under the VPN
    ./vps-mount.nix # ~/VPS = SFTP to the KingHost VPS' root (rclone plus cache), mounted at login
    ./drive-mount.nix # ~/Drive = the Google Drive's root mounted (rclone mount), to browse in Dolphin
    ./arch-legacy-mount.nix # /mnt/arch-antigo = the old Arch archive mounted always (a restic mount)
    ./disk-hygiene.nix # the free space alarm (it notifies with the biggest consumers) plus an expiring trash
    ./downloads-tidy.nix # ~/Downloads as an inbox: loose files sorted into type folders every 30 min
    ./disk-insight.nix # the weekly size trend, the /proc usage sampler and the `disk-report` command
    ./home-subvolumes.nix # VM images and game libraries as nested subvolumes, out of the snapshots
    ./razer-dpi.nix # the OSD for the Razer mouse's onboard DPI button (it polls hidraw)
    ./basic-memory.nix # the MCP memory server over ~/context, shared by Claude Code, codex and agy
    ./vm-boot-drill.nix # the weekly drill: it rebuilds the VM boot test and only speaks on failure
    ./signalsift.nix # my feed, transcript and local LLM daemon (its web UI on 127.0.0.1:7878)
    ./power-profile.nix # the ppd profile's user-side effects: SignalSift's profile, idle Ollama models
  ];
}
