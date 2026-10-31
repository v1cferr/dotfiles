# BESZEL: resource history (CPU/RAM/disk/temps, per host and per Docker container) at
# stats.<domain>, the part Cockpit's Metrics cannot keep. Pairing and why: docs/notes/services/beszel.md
{ config, lib, ... }:

let
  agentPort = 45876;
in
{
  options.my.beszel.hubKey = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "The hub's SSH public key (Add system in its UI). Public material, not a secret.";
  };

  config = lib.mkIf config.my.services.beszel {
    services.beszel.hub = {
      enable = true; # 127.0.0.1:8090 by default; Caddy is the way in
      environment.APP_URL = "https://stats.${config.my.net.domain}";
    };

    # The hub only mints its key on first start, so the agent stays off until the key is
    # declared: a half-paired agent would just log rejected handshakes.
    services.beszel.agent = lib.mkIf (config.my.beszel.hubKey != null) {
      enable = true; # joins the docker group by itself, for the container stats
      environment = {
        KEY = config.my.beszel.hubKey;
        LISTEN = "127.0.0.1:${toString agentPort}"; # the hub is on this same host
      };
    };
  };
}
