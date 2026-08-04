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
    "tor"
    "restic"
    "btrbk"
    "arch-kingston-archive"
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
    tor = true; # SOCKS5 local 127.0.0.1:9050 (só cliente; consumidor = `mega-tor`)
    restic = true; # backup automático (off-disk, diário)
    btrbk = true; # snapshots locais do @home (horário) — complementa o restic
    arch-kingston-archive = true; # TEMPORÁRIO: arquiva o Arch antigo no Drive (desligar após o check)
    cloudflare-ddns = true; # DNS dinâmico (mantém o SSH externo)
    dropbox = true; # sync do ~/Dropbox
    discord-rpc = true; # Rich Presence do Claude Code no Discord
    cs2-backup = true; # backup dos saves do CS2
  };
}
