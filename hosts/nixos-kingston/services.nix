# ═══════════════════════════════════════════════════════════════════════════
# nixos-kingston's SERVICE PANEL: it turns the optional ones on and off in a single place.
# Edit true/false below plus `rebuild`.
#
# It lives in the HOST and not in system/ because the answer is per MACHINE: a laptop does not
# serve media (jellyfin), does not stream its screen (sunshine) and is not a torrent destination.
# The LIST of keys that exist belongs to the repo and lives in system/services/toggles.nix; what
# each machine turns on is here.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  my.services = {
    caddy = true; # the *.v1cferr.dev reverse proxy (inert until the secrets exist)
    jellyfin = true; # the media server (/srv/media)
    ollama = true; # local AI (the Duolingo solver)
    duo = true; # duo-streak-daemon (the automatic Duolingo streak)
    grad-radar = true; # GradRadar at boot plus the call-for-applications monitor 2x/day (V1C-72)
    sunshine = true; # screen streaming for Moonlight
    qbittorrent = true; # the torrent client
    tor = true; # a local SOCKS5 at 127.0.0.1:9050 (client only; the consumer is `mega-tor`)
    restic = true; # the automatic backup (off-disk, daily)
    btrbk = true; # local @home snapshots (hourly), complementing restic
    cloudflare-ddns = true; # dynamic DNS (it keeps the external SSH alive)
    dropbox = true; # ~/Dropbox syncing
    drive-mount = true; # ~/Drive = the Drive's root mounted (rclone mount), showing up in Dolphin
    arch-antigo-mount = true; # /mnt/arch-antigo = the old Arch archive mounted ALWAYS (restic)
    discord-rpc = true; # Claude Code's Rich Presence on Discord
    cs2-backup = true; # a backup of the CS2 saves
  };

  # ── THE EXPOSURE PANEL: who has a subdomain and how far it reaches ─────────
  # It generates Caddy's vhosts (the schema is in system/net/ingress.nix). SWITCHING = changing
  # the `expose` word:
  #   "lan"    -> the LAN plus the router's WireGuard plus the TAILNET (the real remote access today)
  #   "public" -> the internet, subject to the declared `auth`
  #
  # WARNING: "public" today is a DECLARATION, not connectivity: this host is behind CGNAT and
  # nothing gets in (see the CGNAT entry in docs/history/2026/08-august.md). The right gate is
  # already applied; what is missing is the inbound path (a public IP or cloudflared).
  #
  # Omitting `expose` CLOSES (the default is "lan"), so forgetting does not become exposure.
  my.ingress = {
    pos = {
      upstream = 3006;
      routes = {
        "/api/*" = 8006;
      }; # FastAPI; the prefix is NOT stripped, so the same URL holds inside the container
      expose = "public";
      # NO basic_auth, on purpose: the login is going to live in the application (Next.js), and a
      # proxy password in front would mean typing two. Until F2 the page is OPEN, and what it
      # shows are public call-for-application dates and no personal data (none of the three names
      # is rendered). The day there is anything per candidate, the app's login has to exist FIRST.
      comment = "GradRadar (V1C-72), shared with JP and César. Open: auth will come in the app itself (F2).";
    };

    jellyfin = {
      upstream = 8096;
      expose = "public";
      comment = "It has its own login; exposed at the same level as on Arch. The upstream is on loopback (the native service listens on 0.0.0.0).";
    };

    torrent = {
      upstream = 8080;
      expose = "public";
      comment = "qBittorrent: its own login, the same criterion as jellyfin.";
    };

    duo = {
      upstream = 3010;
      proxyConfig = "flush_interval -1"; # SSE (/api/events) with no buffering
      expose = "lan";
      comment = "duo-streak-daemon (V1C-71). It exposes details of the automation, so it never leaves the house.";
    };

    ai = {
      upstream = 11434;
      expose = "lan";
      comment = "Ollama has NO native auth. `lan` is the ONLY protection; do not change it without putting auth in front.";
    };
  };
}
