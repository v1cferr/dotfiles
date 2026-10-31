# COCKPIT: start/stop any systemd unit from the browser (ops.<domain>), the compose stacks
# included through their units. Why Cockpit and the proxy settings: docs/notes/services/cockpit.md
{ config, lib, ... }:

lib.mkIf config.my.services.cockpit {
  services.cockpit = {
    enable = true;
    showBanner = false; # no "Web console: ..." line in every motd/issue
    allowed-origins = [ "https://ops.${config.my.net.domain}" ];
    # Caddy terminates TLS and talks plain HTTP to it; trust its headers for scheme and client IP.
    settings.WebService = {
      AllowUnencrypted = true;
      ProtocolHeader = "X-Forwarded-Proto";
      ForwardedForHeader = "X-Forwarded-For";
    };
  };

  # Loopback only: Caddy is the single way in. The "" resets the unit's own ListenStream.
  systemd.sockets.cockpit.listenStreams = lib.mkForce [
    ""
    "127.0.0.1:${toString config.services.cockpit.port}"
  ];
}
