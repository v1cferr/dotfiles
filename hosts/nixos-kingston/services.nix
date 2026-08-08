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

  # ── PAINEL DE EXPOSIÇÃO: quem tem subdomínio e até onde alcança ────────────
  # Gera os vhosts do Caddy (schema em system/net/ingress.nix). ALTERNAR = trocar
  # a palavra do `expose`:
  #   "lan"    → LAN + WireGuard do roteador + TAILNET (acesso remoto real hoje)
  #   "public" → internet, sujeito ao `auth` declarado
  #
  # ⚠️ "public" hoje é DECLARAÇÃO, não conectividade: este host está atrás de
  # CGNAT e nada entra (ver TODO do CGNAT em docs/ANOTACOES.md). O gate correto
  # já é aplicado; falta o caminho de entrada (IP público ou cloudflared).
  #
  # Omitir `expose` FECHA (default = "lan") — esquecimento não vira exposição.
  my.ingress = {
    pos = {
      upstream = 3006;
      routes = {
        "/api/*" = 8006;
      }; # FastAPI; prefixo NÃO removido, p/ a mesma URL valer no container
      expose = "public";
      auth = {
        v1cferr = "CADDY_POS_HASH_V1CFERR";
        jp = "CADDY_POS_HASH_JP";
      };
      comment = "GradRadar (V1C-72), dividido com o JP. Sem login próprio até o F2 → basic_auth de fora.";
    };

    jellyfin = {
      upstream = 8096;
      expose = "public";
      comment = "Login próprio; exposto no mesmo nível do Arch. Upstream em loopback (o serviço nativo escuta 0.0.0.0).";
    };

    torrent = {
      upstream = 8080;
      expose = "public";
      comment = "qBittorrent — login próprio, mesmo critério do jellyfin.";
    };

    duo = {
      upstream = 3010;
      proxyConfig = "flush_interval -1"; # SSE (/api/events) sem buffer
      expose = "lan";
      comment = "duo-streak-daemon (V1C-71). Expõe detalhes da automação → nunca sai de casa.";
    };

    ai = {
      upstream = 11434;
      expose = "lan";
      comment = "Ollama NÃO tem auth nativa. `lan` é a ÚNICA proteção — não trocar sem pôr auth na frente.";
    };
  };
}
