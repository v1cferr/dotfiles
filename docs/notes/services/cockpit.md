# Cockpit: start and stop services from the browser

`modules/nixos/services/cockpit.nix`, toggle `my.services.cockpit`, subdomain `ops`.

`https://ops.<domain>` opens Cockpit from home and over WireGuard (Caddy answers 403 from
outside). Log in with the local user, turn on "administrative access" (sudo), and the
**Services** tab starts, stops and restarts any unit and shows its journal.

## Two switches, two meanings

- **Stop in Cockpit** frees the resources NOW, but it is temporary: whatever the unit is
  `wantedBy` comes back at the next boot.
- **The toggle** in `hosts/<host>/services.nix` plus a rebuild is the permanent off. If a
  service stays stopped in Cockpit for weeks, that is the signal to flip its toggle.

The compose stacks (`duo`, `grad-radar`, `credit-radar`) are systemd units whose `ExecStop`
is `docker compose down`, so stopping the unit stops the whole stack. A container started
by hand outside Nix has no unit and does not show up: give it a module and a toggle first.

## Why Cockpit

The goal was on/off without paying for an always-on panel. Cockpit is socket-activated:
only `cockpit.socket` sits idle, and `cockpit.service` exists only while a browser has the
page open. It drives systemd, so it reaches the native services and the compose stacks
alike. Docker-only panels (Arcane, Portainer, Dockge) run all the time and do not see the
native units.

## The reverse proxy settings

- The socket listens on `127.0.0.1` only, so Caddy is the single way in.
- Caddy terminates TLS and talks plain HTTP to it, hence `AllowUnencrypted = true` (without
  it Cockpit redirects to its own self-signed HTTPS) and `ProtocolHeader` /
  `ForwardedForHeader` so it trusts Caddy's view of the scheme and the client.
- `allowed-origins` must hold `https://ops.<domain>`, or the WebSocket is refused and the
  page stays blank after login.
- `LoginTo` stays `false` (the nixpkgs default): logging into other hosts is the surface of
  CVE-2026-4631 on versions before 360.

## Plugins

- `cockpit-machines`: the libvirt guests, so the Windows VM is started, stopped and used
  (its console opens in the page) from the browser, the same "only run what I use" goal.
- `cockpit-files`: a file browser, root-capable after sudo, for `/srv/media` and
  `/srv/photos` from the phone.

Left out on purpose:

- `cockpit-podman` and `cockpit-zfs` are in nixpkgs, but this host runs Docker on btrfs.
- No Docker plugin: the community `cockpit-docker` fork is not in nixpkgs. A container worth
  managing gets a module and a toggle instead, which Cockpit already drives.
- The Metrics page shows live values only. History needs PCP, which nixpkgs dropped
  (upstream archived). Beszel at `stats.<domain>` covers history.
- Kernel dump is hidden through `/etc/cockpit/kdump.override.json`: its manifest only checks
  that `kexec` exists. Software updates, SELinux and Diagnostic reports hide themselves
  (their conditions fail on NixOS).
