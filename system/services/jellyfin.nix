# ═══════════════════════════════════════════════════════════════════════════
# Jellyfin — servidor de mídia nativo (systemd, 24/7, sobe no boot).
#
# Migrado do stack Docker do Arch pro serviço nativo do NixOS: isolado no usuário
# 'jellyfin', sem overhead de container. O resto do stack antigo (jellyseerr, *arr,
# qbittorrent, cloudflared) entra depois, um módulo por vez neste system/media/.
#
# Biblioteca em /srv/media (SSD): compartilhada via grupo 'media' (eu gerencio os
# arquivos; o jellyfin lê). As BIBLIOTECAS em si (o que é Filme/Série) se configuram
# na web UI (localhost:8096) no 1º acesso — isso vive no DB do jellyfin, não aqui.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  # Grupo compartilhado da mídia: dono = eu (copio/gerencio), leitura = jellyfin.
  users.groups.media = { };
  users.users.v1cferr.extraGroups = [ "media" ]; # (soma com wheel/networkmanager)
  users.users.jellyfin.extraGroups = [ "media" ]; # o serviço lê a biblioteca

  # /srv/media com setgid (o '2' em 2775): tudo criado dentro herda o grupo 'media',
  # então jellyfin/*arr e eu enxergamos os mesmos arquivos sem brigar por permissão.
  systemd.tmpfiles.rules = [
    "d /srv/media          2775 v1cferr media - -"
    "d /srv/media/media    2775 v1cferr media - -" # filmes/séries (biblioteca)
    "d /srv/media/torrents 2775 v1cferr media - -" # downloads (futuro qbittorrent)
  ];

  services.jellyfin = {
    enable = true;
    openFirewall = true; # abre 8096/8920 (web) + 1900/7359 UDP (descoberta DLNA) na LAN
  };
}
