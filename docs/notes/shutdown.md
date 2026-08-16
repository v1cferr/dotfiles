# shutdown

Module: [`system/core/shutdown.nix`](../../system/core/shutdown.nix)

How long systemd waits for a unit to stop before the SIGKILL.

## The symptom, and the number that gave it away

"A stop job is running…" and the shutdown taking a minute and a half. Measured on 09/08/2026 over
the last 10 boots: **90.3 / 90.4 / 90.5 / 90.6 s**. Far too round to be real work. That is not the
system doing something, it is a TIMEOUT firing, and the timeout was systemd's default: 90 s.

## A single culprit, on the user's side

**VS Code.** It runs in a session scope (`app-code-<pid>.scope`, created by GLib when launching
the `.desktop`) and it does not answer the SIGTERM. Every shutdown closed the same way:

```text
app-code-*.scope: Stopping timed out. Killing.
```

Before VS Code, the same pattern showed up with Chromium. It is Electron behavior, not this
machine's. EVERYTHING else (docker, jellyfin, the network, the unmounts, swap) stops in under 2 s,
so there was nothing to optimize, only waiting on a process that was never going to answer.

## What the change does not do

It does not start killing anything that used to die a natural death. **The SIGKILL already
happened**, 90 s later. Whoever saves state on SIGTERM (pipewire, dropbox, rclone, all the
daemons) takes under 1 s and keeps saving; whoever ignores the signal merely stops charging us the
wait.

## Why 5 s on the user side and 30 s on the system side

The two sides have different tenants, and a single value would serve both badly.

- **User**: desktop apps. Whoever was going to save has saved; what is left is a hung Electron.
  5 s is generous slack for an honest SIGTERM.
- **System**: `docker compose down` sits in the ExecStop of duo and grad-radar, and `down` gives
  EACH container 10 s of grace before killing it. A tight ceiling here would SIGKILL those stacks'
  Postgres in the middle of the down. It does not corrupt anything, but it comes back doing WAL
  recovery on the next boot, and the price shows up far from the cause. 30 s covers the down with
  room to spare and is still 3x faster than the default.

## It is a default, not a ceiling

A unit with its OWN `TimeoutStopSec` ignores everything here. Today that is qbittorrent (30 min),
jellyfin (15 s), caddy (5 s), hyprpolkitagent (5 s) and `user@.service` (2 min, from upstream). If
the shutdown ever gets slow again, look first for whoever declared their own value:

```sh
systemctl show <unit> -p TimeoutStopUSec
```

## The two sides have different APIs, and the asymmetry is a real trap

`systemd.extraConfig` WAS REMOVED (26.05 wants `systemd.settings.Manager`, freeform), but
`systemd.user.extraConfig` is still the only form on the user side, because `systemd.user.settings`
does NOT exist (checked in the options).

The way that fails is the worst possible: writing to the removed option, the `nix eval` of the
generated `system.conf` passes and comes out WITHOUT the line. Nothing warns you. So the validation
is not "did it build?", it is READING the generated file:

```sh
nix eval --raw '.#nixosConfigurations.nixos-kingston.config.environment.etc."systemd/system.conf".text'
```

To check the effect without a stopwatch, the journal's two stamps:

```sh
journalctl -b -1 -o short-precise | grep -E "Stopping User Manager|Journal stopped"
```
