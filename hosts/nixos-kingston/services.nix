# ═══════════════════════════════════════════════════════════════════════════
# PAINEL DE SERVIÇOS do nixos-kingston — liga/desliga os opcionais num lugar só.
# Editar true/false abaixo + `rebuild`.
#
# Mora no HOST e não no system/ porque a resposta é por MÁQUINA: um laptop não
# serve mídia (jellyfin), não faz streaming de tela (sunshine) e não é destino de
# torrent. A LISTA de chaves que existem é do repo e fica em
# system/services/toggles.nix; o que cada máquina liga é aqui.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  my.services = {
    caddy = true; # proxy reverso *.v1cferr.dev (inerte até os segredos existirem)
    jellyfin = true; # servidor de mídia (/srv/media)
    ollama = true; # IA local (solver do Duolingo)
    duo = true; # duo-streak-daemon (ofensiva automática do Duolingo)
    sunshine = true; # streaming de tela p/ Moonlight
    qbittorrent = true; # cliente torrent
    tor = true; # SOCKS5 local 127.0.0.1:9050 (só cliente; consumidor = `mega-tor`)
    restic = true; # backup automático (off-disk, diário)
    btrbk = true; # snapshots locais do @home (horário) — complementa o restic
    cloudflare-ddns = true; # DNS dinâmico (mantém o SSH externo)
    dropbox = true; # sync do ~/Dropbox
    drive-mount = true; # ~/Drive = raiz do Drive montada (rclone mount), aparece no Dolphin
    discord-rpc = true; # Rich Presence do Claude Code no Discord
    cs2-backup = true; # backup dos saves do CS2
  };
}
