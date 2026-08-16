# Tor, CLIENT ONLY: a SOCKS5 on 127.0.0.1:9050 for a CLI that accepts a proxy (`mega-dl`).
# Never a relay or exit. The wiki's 9063 port does not exist in this nixpkgs.
{ config, ... }:

{
  services.tor = {
    enable = config.my.services.tor;
    client.enable = true; # this is what opens the SOCKS5 on 127.0.0.1:9050
    settings = {
      ClientOnly = true; # it locks the role: never a relay, never an exit
      SafeSocks = true; # DNS resolved outside Tor is an error, not a silent leak
    };
  };
}
