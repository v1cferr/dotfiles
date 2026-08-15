# ═══════════════════════════════════════════════════════════════════════════
# INGRESS = the SINGLE SOURCE of who is exposed and how far (rule 11). Every service that gets a
# subdomain declares itself HERE, and the Caddyfile is GENERATED from here, never the other way
# around.
#
# THE PROBLEM THIS SOLVES: before, each service's reach was implicit and scattered through the
# Caddyfile. `duo` and `ai` had a hand-written `respond @externo 403`; `jellyfin` and `torrent`
# simply did NOT, and only the comment next to them said that was on purpose. To know what was
# exposed you had to read 60 lines of Caddyfile and notice an ABSENCE, which is the worst way to
# encode a security decision, because forgetting to write it becomes "exposed" in silence. With
# `expose`, the default is `lan`: forgetting CLOSES.
#
# HOW TO SWITCH: one word in the host's panel (hosts/*/services.nix).
#   expose = "lan"    -> the home network only (LAN plus the router's WireGuard)
#   expose = "public" -> reachable from outside, subject to the declared `auth`
#
# `public` really WORKS: the router has a public IP on pppoe-wan and forwards 80/443 here (there
# was a CGNAT scare on 07/08/2026 that proved false, see docs/history/2026/08-august.md). A
# service marked `public` is reachable from the internet TODAY.
#
# The option lives in net/ and not inside caddy.nix because it describes NETWORK REACH, not a
# proxy detail. Today Caddy is the only consumer, but the decision is not its.
# ═══════════════════════════════════════════════════════════════════════════
{ lib, ... }:

{
  options.my.ingress = lib.mkOption {
    default = { };
    description = "Services with a subdomain of their own under `my.net.domain`. It generates Caddy's vhosts (and, in the future, the tunnel's ingress).";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          upstream = lib.mkOption {
            type = lib.types.port;
            description = "The port on 127.0.0.1 that serves everything not matching a `routes` entry.";
          };

          # A CLOSED default on purpose: see the header's block. Forgetting to declare it cannot
          # mean "open to the internet".
          expose = lib.mkOption {
            type = lib.types.enum [
              "lan"
              "public"
            ];
            default = "lan";
            description = "The reach: `lan` (home plus WireGuard) or `public` (the internet). A closed default, so omitting it NEVER exposes anything.";
          };

          # user -> the name of the environment variable carrying the bcrypt hash (the value comes
          # from sops through caddy.env; rule 12: no secret in the store).
          # It only applies to whoever comes from OUTSIDE; on the home network it opens directly.
          auth = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            example = {
              v1cferr = "CADDY_POS_HASH_V1CFERR";
            };
            description = "The basic_auth required from whoever comes from outside: user -> the .env variable holding the bcrypt hash.";
          };

          # A path prefix -> a port. Evaluated BEFORE the `upstream`, in the order Caddy resolves
          # `handle` (most specific first).
          routes = lib.mkOption {
            type = lib.types.attrsOf lib.types.port;
            default = { };
            example = {
              "/api/*" = 8006;
            };
            description = "Per-prefix routes that go to a different port from the `upstream`.";
          };

          proxyConfig = lib.mkOption {
            type = lib.types.lines;
            default = "";
            example = "flush_interval -1";
            description = "Extra directives INSIDE the upstream's `reverse_proxy` (SSE with no buffering, say).";
          };

          comment = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Why this service exists and why this reach; it goes as a comment into the generated Caddyfile.";
          };
        };
      }
    );
  };
}
