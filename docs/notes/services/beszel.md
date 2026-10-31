# Beszel: the resource history Cockpit cannot keep

`modules/nixos/services/beszel.nix`, toggle `my.services.beszel`, subdomain `stats`.

`https://stats.<domain>` shows CPU, RAM, disk, network and temperatures over time, for the
host and for every Docker container, the ones started by hand outside Nix included. It
answers from home and over WireGuard only (Caddy answers 403 from outside).

## Why it exists next to Cockpit

Cockpit's Metrics page shows live values only: its history needs PCP, and nixpkgs dropped
PCP (upstream archived). The question "what was eating the machine yesterday" needs history,
and Beszel is the light way to get it: one hub and one small agent, both in nixpkgs. Unlike
Cockpit it is always on, which is the price of recording.

Pin: 0.18.4 or newer (CVE-2026-27734, an authenticated user reaching the Docker API).

## Pairing, the one manual step

The hub mints its SSH key pair on first start, so the key cannot be known at build time:

1. Rebuild with the toggle on. Only the hub runs; the agent waits for the key.
2. Open `https://stats.<domain>` and create the admin account.
3. **Add system**: name it after the host, host `127.0.0.1`, port `45876`. Copy the public key
   it shows.
4. Set `my.beszel.hubKey = "ssh-ed25519 ...";` in `hosts/<host>/services.nix` and rebuild.
   The key is public material, so it lives in the repo and not in sops.

The agent listens on loopback only, and the firewall stays closed: the hub is on the same
host. It joins the `docker` group by itself (the nixpkgs module), which is how it sees the
containers.
