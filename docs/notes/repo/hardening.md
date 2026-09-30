# hardening: a sandbox for this repo's own root services

`my.systemd.hardened`, a read-only option in `system/core/hardening.nix`, is one `serviceConfig`
baseline that a consumer merges in: `serviceConfig = config.my.systemd.hardened // { ... }`. One
owner for the set, so a unit either takes all of it or says, in its own comment, what it drops.

## Why

On 30/09/2026 all 14 custom root services of this repo scored **9.6 UNSAFE** in
`systemd-analyze security`, the worst it gives: not one sandboxing option was set. systemd runs a
service with every privilege root has unless told otherwise, and the NixOS wiki's
[Systemd/Hardening](https://wiki.nixos.org/wiki/Systemd/Hardening) page is the reference for
narrowing it.

## What the baseline takes away

No new privileges, a private `/tmp`, a private network namespace with only Unix sockets, `/usr`,
`/boot` and `/etc` read-only, the homes read-only, and no kernel modules, kernel logs, clock,
hostname, cgroups, namespaces, realtime, SUID or foreign architectures. It deliberately does NOT
set `ProtectKernelTunables` (a taker writes `/sys`), `PrivateDevices` (`btrfs device stats` may
resolve devices) or `ProtectHome = true` (the docker CLI reads `/root/.docker`).

## Who takes it, and the score

MEASURED with `systemd-analyze security --offline=true` over the unit files, before on the running
system and after on the built one, so the two sides are the same kind of measurement (the live
score reads 9.6 where the offline one reads 9.4):

| Unit | What it does | Before | After |
| --- | --- | ---: | ---: |
| `btrfs-device-stats` | reads the I/O error counters | 9.4 | 5.3 |
| `btrfs-reclaim-tuning` | writes the reclaim knobs in `/sys` | 9.4 | 5.3 |
| `docker-volume-prune` | talks to the docker socket | 9.4 | 5.3 |
| `logid-reapply` | restarts logid over D-Bus | 9.4 | 5.3 |

## Who does not, and why

- **`btrfs-alert-scrub`, `btrfs-alert-devstats`**: they reach the user's session (`runuser`, the
  D-Bus under `/run/user`) to raise the only alarm a failing disk gets. A restriction that broke
  them would fail in silence, which costs more than it saves.
- **`openrgb-gpu`**: it needs the GPU's i2c bus.
- **`vpn-fai`, `vpn-ufscar`**: they create interfaces and routes, which is network and capability
  work by definition.
- **`duo-stack`, `grad-radar*`, `credit-radar*`**: docker compose wrappers, whose real surface is
  the containers and the root-equivalent docker socket, not the wrapper.

A new root oneshot of the same shape takes the baseline from the start.
