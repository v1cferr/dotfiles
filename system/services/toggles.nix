# ═══════════════════════════════════════════════════════════════════════════
# THE INTERFACE of the optional services: the LIST of keys that exist. Nothing is turned on here:
# the value (true/false) is EACH MACHINE's decision and lives in the host's panel,
# hosts/<host>/services.nix.
#
# Why the declaration stays here and not in each service module (04/08/2026): `osConfig` only sees
# the NixOS namespace, so an option read by a home module (dropbox, discord-rpc, cs2-backup) HAS
# to be declared by a SYSTEM module. Spreading the declarations out would leave three orphans
# needing a central file anyway, which is worse than a single list that also serves as a readable
# contract of what this repo knows how to turn on and off.
#
# Each service reads its flag through config.my.services.<name> (system) or
# osConfig.my.services.<name> (home-manager).
#
# The ESSENTIALS stay OUT on purpose (tailscale, mouse/logid, the hypr* desktop, keyring,
# earlyoom, fail2ban, fwupd), so they cannot be turned off by accident. The VPN is on demand
# (out).
#
# A new key here WITH no value in the host is born `false` (mkEnableOption), so a new service that
# does not come up is the symptom; the remedy is the line in the host's panel.
# ═══════════════════════════════════════════════════════════════════════════
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
