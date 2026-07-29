# ═══════════════════════════════════════════════════════════════════════════
# PAINEL CENTRAL DE SERVIÇOS — liga/desliga os serviços OPCIONAIS num lugar só.
# Editar o valor abaixo (true/false) + `rebuild`. Cada serviço lê seu flag via
# config.my.services.<nome> (sistema) ou osConfig.my.services.<nome> (home-manager).
#
# ESSENCIAIS ficam FORA de propósito (tailscale, mouse/logid, desktop hypr*, keyring,
# earlyoom, fail2ban, fwupd) — não dá pra desligar por engano. VPN é sob-demanda (fora).
# ═══════════════════════════════════════════════════════════════════════════
{ lib, ... }:

{
  options.my.services = lib.genAttrs [
    "jellyfin"
    "ollama"
    "duo"
    "sunshine"
    "qbittorrent"
    "restic"
    "cloudflare-ddns"
    "dropbox"
    "discord-rpc"
    "cs2-backup"
  ] (n: lib.mkEnableOption n);

  # ── PAINEL: edite aqui pra ligar/desligar ──────────────────────────────────
  config.my.services = {
    jellyfin = true; # servidor de mídia (/srv/media)
    ollama = true; # IA local (solver do Duolingo)
    duo = true; # duo-streak-daemon (ofensiva automática do Duolingo)
    sunshine = true; # streaming de tela p/ Moonlight
    qbittorrent = true; # cliente torrent
    restic = true; # backup automático
    cloudflare-ddns = true; # DNS dinâmico (mantém o SSH externo)
    dropbox = true; # sync do ~/Dropbox
    discord-rpc = true; # Rich Presence do Claude Code no Discord
    cs2-backup = true; # backup dos saves do CS2
  };
}
