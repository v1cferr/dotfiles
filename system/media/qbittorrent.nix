# ═══════════════════════════════════════════════════════════════════════════
# qBittorrent — cliente de download (headless qbittorrent-nox + Web UI), systemd.
#
# Roda no grupo 'media' (mesmo do jellyfin) pra gravar em /srv/media/torrents. A
# Web UI fica na 8080 (igual ao WEBUI_PORT do stack Docker antigo). O SAVE PATH e
# categorias se ajustam na Web UI (localhost:8080) — isso é estado do qBittorrent.
# Login inicial: usuário 'admin', senha temporária no log (journalctl -u qbittorrent).
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  services.qbittorrent = {
    enable = true;
    openFirewall = true; # abre a porta de torrent (peers) + a Web UI na LAN
    webuiPort = 8080; # painel web (mesmo do setup antigo)
    user = "qbittorrent";
    group = "media"; # grupo compartilhado → escreve na biblioteca /srv/media
  };
}
