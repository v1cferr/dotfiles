# Tor, CLIENT ONLY: a SOCKS5 on 127.0.0.1:9050 for a CLI that takes a proxy (`mega-dl`), never a
# relay or exit. Why a native proxy over torsocks: docs/notes/apps/mega.md
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
