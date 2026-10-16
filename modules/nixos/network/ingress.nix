# INGRESS: the SSOT of who gets a subdomain and how far; Caddy and the tunnel are generated from
# it, and the default `lan` CLOSES when `expose` is forgotten: docs/notes/network/caddy.md
{ config, lib, ... }:

{
  options.my.ingress = lib.mkOption {
    default = { };
    description = "Services with a subdomain of their own under `my.net.domain`. It generates Caddy's vhosts and the Cloudflare Tunnel's ingress.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          upstream = lib.mkOption {
            type = lib.types.port;
            description = "The port on 127.0.0.1 that serves everything not matching a `routes` entry.";
          };

          # A CLOSED default: forgetting to declare it cannot mean "open to the internet".
          expose = lib.mkOption {
            # `tunnel` gets NO Caddy vhost: Caddy's 443 would be a way around the Access gate.
            type = lib.types.enum [
              "lan"
              "public"
              "tunnel"
            ];
            default = "lan";
            description = "The reach: `lan` (home plus WireGuard), `public` (the internet through Caddy) or `tunnel` (only through the Cloudflare Tunnel, gated by Access at the edge). A closed default, so omitting it NEVER exposes anything.";
          };

          # user -> the env var holding the bcrypt hash (from sops, rule 12). It applies only
          # to whoever comes from OUTSIDE.
          auth = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            example = {
              v1cferr = "CADDY_POS_HASH_V1CFERR";
            };
            description = "The basic_auth required from whoever comes from outside: user -> the .env variable holding the bcrypt hash.";
          };

          # A path prefix -> a port, evaluated BEFORE the `upstream` (most specific first).
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

          # A web UI worth opening from Vicinae; null for an API, a webhook or an MCP endpoint.
          launcher = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                options = {
                  title = lib.mkOption {
                    type = lib.types.str;
                    description = "The name the launcher shows.";
                  };
                  glyph = lib.mkOption {
                    type = lib.types.str;
                    default = "md-web";
                    description = "A JetBrainsMono Nerd Font glyph name for its icon.";
                  };
                };
              }
            );
            default = null;
            description = "An entry in Vicinae that opens https://<name>.<domain> (modules/home/desktop/vicinae/scripts.nix).";
          };
        };
      }
    );
  };
  # Caddy owns `auth`, `routes` and `proxyConfig`; on a tunnel entry they would be dead config (rule 16).
  config.assertions = lib.concatLists (
    lib.mapAttrsToList (name: s: [
      {
        assertion = s.expose != "tunnel" || (s.auth == { } && s.routes == { } && s.proxyConfig == "");
        message = "my.ingress.${name}: a `tunnel` entry maps one hostname to one port; `auth`, `routes` and `proxyConfig` are Caddy's and would be ignored.";
      }
      # Access has no browser login on a tunnel name, so a launcher entry there opens an error page.
      {
        assertion = s.expose != "tunnel" || s.launcher == null;
        message = "my.ingress.${name}: a `tunnel` entry sits behind Access with no browser login; it cannot have a `launcher`.";
      }
    ]) config.my.ingress
  );
}
