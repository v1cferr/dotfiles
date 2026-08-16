# caddy

Module: [`system/services/caddy.nix`](../../system/services/caddy.nix)

The reverse proxy for every exposed service, under `*.<domain>`, with a WILDCARD certificate from
Let's Encrypt through the DNS-01 challenge.

It restores the ingress that existed on Arch and that the migration to NixOS left behind, now
declarative.

## One wildcard site block, not a vhost per subdomain

That is ONE certificate instead of ~10 simultaneous ACME requests. Routing by name comes from the
`@host` matchers, and an unmapped subdomain falls into the 404 at the end.

**DNS-01 and not HTTP-01** because a wildcard is only issued through DNS-01. The price is a Caddy
built with the `dns.providers.cloudflare` plugin. On Arch that meant building with xcaddy and
HIDING the binary in `/usr/local/bin`, because a `pacman -Syu` once overwrote the custom binary and
took the whole proxy down. On Nix the package IS the declaration, so that problem stops existing.

The `hash` in the derivation belongs to the Go vendor and changes when either the Caddy version or
the plugin changes. A rebuild complaining about it means recomputing with `lib.fakeHash` and
reading the expected value in the error.

## `propagation_timeout -1` is not a guess

certmagic's LOCAL propagation check fails ON THIS host even when forcing public resolvers, while
the record does propagate for real: 8.8.8.8, 1.1.1.1 and the authoritative server all confirm it,
and it is the world that LE queries.

A fixed 30s wait with the local check turned off makes LE validate directly. Without it the
issuance HANGS.

## The vhosts are GENERATED from the ingress SSOT

The Caddyfile stopped being written by hand: what decides reach is
[`system/net/ingress.nix`](../../system/net/ingress.nix), where forgetting to declare CLOSES
instead of exposing, because the `expose` default is `lan`.

**Concatenation and not interpolation** when emitting `{$VAR}`: `"{$" + v + "}"` is the only
unambiguous form, because `$${v}` in a Nix string is a SYNTAX ERROR, not an escape. It bit once:
the first generated file came out with a literal `{$${v}}`, which would become an empty hash at
runtime.

## The auto-gate, and why the secret list is derived

The service only activates when all FOUR secrets exist. Until they are provisioned it stays INERT
and the system keeps building, which matters because an empty `{$VAR}` would become an empty
basic_auth hash and Caddy would refuse the ENTIRE config.

**The hashes are not literals in the gate**, they are derived from whoever declares `auth` in the
SSOT. When they were fixed, removing basic_auth from a service left the gate requiring a secret
nobody read anymore, and the day that item left Bitwarden, Caddy would go inert and take jellyfin,
torrent, ai and duo down with it. A service that goes down because of a password it does not use is
the worst kind of coupling: invisible until the day it matters.

The same reasoning applies to the `.env`: leaving a `CADDY_*_HASH` there after removing the
basic_auth renders a secret nothing consumes, and the next reader cannot tell it is leftover.

**Single quotes around the hashes** in the `.env`: bcrypt contains `$`, and the old setup's file
already documented that without them the value is mangled before reaching the process.

## `client_ip` and not `remote_ip`, before the trap exists

The "home" matcher is the LAN plus the router's WireGuard plus loopback, defined once and reused by
every handle.

The `10.10.10.0/24` works because the WireGuard server is the ROUTER and the wg-to-lan path does
not NAT, so the source IP arrives preserved. If WireGuard ever moves to the host, that range moves
with it.

Today `client_ip` and `remote_ip` are identical, since with no trusted proxy the client IS the
connection. The difference shows up with cloudflared, which delivers over LOOPBACK: with
`remote_ip`, all the tunnel traffic would become "home" and bypass basic_auth SILENTLY. Using
`client_ip` now costs nothing and removes the trap before it exists.

**Do NOT add `trusted_proxies` while there is no tunnel.** Without it the `X-Forwarded-For` header
is ignored, which is what we want; with it, any local process could start forging the source IP.

Two things that changed with Tailscale leaving (08/08/2026): this range is now what REMOTE ACCESS
goes through, and the old `100.64.0.0/10` (the tailnet) went out, which is just as well, because
that range is the SAME one carrier CGNAT uses, so an external client behind an ISP NAT could
present an address from it and be treated as home.

On Arch this list was duplicated and DIVERGENT: `duo` included the WireGuard range and `ai` did
not, from a forgotten backfill. Unifying it EXTENDS `ai`'s access to the VPN clients, which is a
conscious decision and not a side effect.

## The fail2ban jail lives here on purpose

It is in this module and not next to the service because the jail only exists because of this
proxy: whoever deletes the vhost has to delete the jail with it, and the coupling stays visible.

basic_auth only returns 401 when the password is wrong, so a 401 on a gated host is a failed
attempt and not normal browsing. The hosts come DERIVED from the SSOT, so declaring a new service
with `auth` already enters the jail with no hand-edited failregex.

**With no host having basic_auth there is no jail at all**, and that is deliberate: an empty
`authHostsRe` would generate `"host":"()"`, a failregex that matches nothing. The jail would stay
green in `fail2ban-client status` while protecting nothing. Better not to exist than to exist
lying.

That is also why it uses `optionalAttrs` and not `mkIf` on `settings`: the fail2ban module injects
`enabled = true` into every DECLARED jail, so emptying the settings would still emit the section.

**The filters depend on the ORDER OF THE KEYS in the JSON access log** (remote_ip, then host, then
status, with a non-greedy `.+?`). A Caddy bump can break them SILENTLY: the service stays up and
simply stops banning. Validate with `fail2ban-regex` on every bump. The log has to be `format json`
to stderr, which is where the jail reads from.

## The first `allowedTCPPorts` in the repo

Everything else uses the upstream module's `openFirewall`, but `services.caddy` does not have one.
The router has been forwarding 80/443/2222 since the old setup, and what blocked was the NixOS
firewall, on by default. 80 stays open because Caddy redirects to 443, and because one day it might
be needed for the HTTP-01 of a domain without DNS-01.

## The loopback port map

A new project picks a free one and WRITES IT DOWN here, otherwise the next collision is silent.

| Port | Service | Port | Service |
| --- | --- | --- | --- |
| 3000 | open-webui | 3001 | spendflow |
| 3003 | homepage | 3004 | filebrowser |
| 3005 | housing-radar | 3006 | GRAD-RADAR (front) |
| 3010 | duo-web | 8000 | spendflow-api (reserved) |
| 8006 | GRAD-RADAR (api) | 8010 | duo-api |
| 8080 | qbittorrent | 8096 | jellyfin |
| 11434 | ollama | | |

## Turning it on, once

1. Cloudflare: an API token with `Zone:Read + DNS:Edit` ON THE ZONE. Separate from the DDNS token.
2. `caddy hash-password` once per basic_auth user.
3. Bitwarden: create the items, with the VALUE always in the *password* field:
   `Caddy ACME Email`, `Caddy Cloudflare DNS`, `Caddy Pos Hash v1cferr`, `Caddy Pos Hash jp`.
4. Add the four lines to `secrets/bitwarden-secrets.json`.
5. `sync-secrets`, then rebuild.
6. DNS on Cloudflare: `pos.<domain>` as a CNAME to `ssh.<domain>`, proxied=false. The `ssh` A
   record is the IP anchor, maintained by the DDNS (see [network](network.md)).

## State

`/var/lib/caddy` holds the ACME account and the certificates. It is not declared, and it is worth
backing up, because LE limits 5 DUPLICATE certificates per week: losing the store costs a reissue
window, not just a rebuild.

The Caddyfile has ONE OWNER, Nix (rule 14), so never a `caddy reload` writing over it.
