# THE INTERFACE of the optional services: the list of keys that EXIST. The value is each host's
# decision, in hosts/<host>/services.nix. Why centralized: docs/notes/services/service-toggles.md
{ lib, ... }:

{
  options.my.services = lib.genAttrs [
    "caddy"
    "jellyfin"
    "ollama"
    "duo"
    "grad-radar"
    "sunshine"
    "qbittorrent"
    "tor"
    "restic"
    "btrbk"
    "cloudflare-ddns"
    "dropbox"
    "drive-mount"
    "arch-antigo-mount"
    "discord-rpc"
    "cs2-backup"
  ] (n: lib.mkEnableOption n);
}
