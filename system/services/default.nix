# Serviços de sistema: backup, hooks, mídia e IA (daemons/systemd).
{ ... }:

{
  imports = [
    ./restic.nix # backup cifrado do estado do usuário (repo no HDD por ora)
    ./claude-code.nix # hooks do Claude Code (managed-settings /etc) → Discord Rich Presence
    ./jellyfin.nix # servidor de mídia Jellyfin (nativo, systemd, biblioteca em /srv/media)
    ./qbittorrent.nix # cliente de download (Web UI 8080; grava em /srv/media/torrents)
    ./ollama.nix # runtime de IA local (CPU); solver do duo-streak-daemon
    ./duo.nix # stack do duo-streak-daemon (compose declarativo; auto-ativa com o segredo)
  ];
}
