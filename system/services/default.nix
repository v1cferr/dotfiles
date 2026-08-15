# System services: backup, hooks, media and AI (daemons/systemd).
{ ... }:

{
  imports = [
    ./toggles.nix # THE INTERFACE: it declares the my.services.* keys (the VALUES belong to the host)
    ./caddy.nix # the reverse proxy for *.<domain> (a DNS-01 wildcard cert) plus the fail2ban jail
    ./restic.nix # the encrypted backup of the user's state (the repo is on the HDD for now)
    ./arch-legacy.nix # the mountpoint plus the SSOT of the old Arch archive (home is what mounts it)
    ./btrbk.nix # hourly btrfs snapshots of @home (a local undo; it is NOT a backup)
    ./claude-code.nix # Claude Code's hooks (managed-settings in /etc) for the Discord Rich Presence
    ./jellyfin.nix # the Jellyfin media server (native, systemd, the library in /srv/media)
    ./qbittorrent.nix # the download client (a Web UI on 8080; it writes to /srv/media/torrents)
    ./ollama.nix # the local AI runtime (CPU); duo-streak-daemon's solver
    ./duo.nix # duo-streak-daemon's stack (a declarative compose; it self-activates with the secret)
    ./grad-radar.nix # GradRadar's stack at boot plus the call-for-applications monitor's timer
    ./docker.nix # the engine's weekly prune (the POLICY only; what turns docker on are the stacks)
    ./sunshine.nix # remote screen streaming (Moonlight); KMS capture, access only through WireGuard
  ];
}
