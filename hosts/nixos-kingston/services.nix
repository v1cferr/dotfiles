# THE PANEL: which optional services and subdomains THIS machine turns on. Edit and rebuild.
# The keys come from system/services/toggles.nix; the reach rules from system/net/ingress.nix.
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
    dropbox = true; # ~/Dropbox syncing
    drive-mount = true; # ~/Drive = the Drive's root mounted (rclone mount), showing up in Dolphin
    arch-antigo-mount = true; # /mnt/arch-antigo = the old Arch archive mounted ALWAYS (restic)
    discord-rpc = true; # Claude Code's Rich Presence on Discord
    basic-memory = true; # the MCP memory server over ~/context (Claude Code, codex and agy share it)
    cs2-backup = true; # a backup of the CS2 saves
  };

  # EXPOSURE: `expose` is "lan" (home plus WireGuard) or "public" (internet, subject to `auth`).
  # Omitting it CLOSES. Today "public" is a declaration, not connectivity: this host is behind CGNAT.
  my.ingress = {
    pos = {
      upstream = 3006;
      routes = {
        "/api/*" = 8006;
      }; # FastAPI; the prefix is NOT stripped, so the same URL holds inside the container
      expose = "public";
      # NO basic_auth: the login belongs to the app (F2). Until then the page shows only public
      # dates and no personal data. Anything per candidate needs the app's login FIRST.
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
