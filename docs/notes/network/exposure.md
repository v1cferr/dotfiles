# exposure: the house seen from outside

`pkgs/exposure-check.nix`, run weekly by the canary's `exposure` job. A GitHub runner is OFF my
network, so it sees exactly what an attacker sees, which no check inside the house can: from here
the split-DNS answers `192.168.1.10` and every port the LAN is allowed to reach looks open.

## What it checks

1. **Every TCP port of the anchor** (`ssh.<my.net.domain>`), with `nmap -p-`, against what
   [`hosts/cudy-wr3000/uci/firewall.conf`](../../../hosts/cudy-wr3000/uci/firewall.conf) opens on the WAN: the DNAT
   forwards and the router's own ACCEPT rules. The expected list is READ from the mirror, never
   typed, so it has one owner (rule 11). An open port the mirror does not declare FAILS: that is a
   forward added by hand on the router, or a service on it listening on the WAN by mistake.
2. **Every open port that answers `SSH-`** goes through [ssh-audit](https://github.com/jtesta/ssh-audit),
   and any recommendation or a non-zero exit is reported.
3. **The methods THIS machine's sshd offers** to a login with no credential at all (`ssh -o
   PreferredAuthentications=none`), which must be exactly `publickey,keyboard-interactive`. A bare
   `password` in that list would mean the TOTP in the PAM stack was bypassed, which is the failure
   the config cannot show by itself: [network](network.md#the-exposed-port-what-the-numbers-say-and-what-actually-defends-it).

The anchor and the port come from the host's evaluated config (`my.net.domain`,
`services.openssh.ports`), passed in by `flake.nix`, so a port change moves the check with it.

## What only warns

- **A declared port that does not answer**: the machine behind it may simply be off. `2223` is my
  brother's PC, which sleeps.
- **ssh-audit findings on ANOTHER machine's sshd**: `2223` is his Windows, whose config is not in
  this repo and cannot be fixed from here. It is reported, never judged, so it cannot keep my
  canary red for a week.

## What it does NOT cover, on purpose

- **UDP.** A WireGuard port answers nothing to an unauthenticated packet, so `nmap -sU` can only
  say `open|filtered` for `51820`, and a UDP sweep of every port takes hours. The declared UDP
  ports are the router's own and change rarely.
- **IPv6.** The anchor is an A record; the v6 side of the router is its own question, in
  [router-hardening](../../guides/router-hardening.md).
- **Anything behind a login.** It never authenticates. The probe uses the one allowed user with the
  `none` method, which sshd answers with the method list and counts as nothing.

## Why this is safe to run against my own house

The scan is a single weekly sweep from a runner address that changes each run, and fail2ban does
not react to it (no authentication fails).

**`PerSourcePenalties` DOES react, and it broke the first run (29/09/2026).** ssh-audit completes a
key exchange and leaves without authenticating, which sshd penalises, and the `min:20s` floor in
this config makes that at least 20 seconds. The method probe ran right after it, got no method
list, and the job failed with `2222 offers []` while ssh-audit had just reported the same port
clean. So the probe now runs FIRST, retries once after 30s (past the floor), and a failure prints
the probe's own last line instead of an empty list. `2223` showed the same blank for its own
reason: the router's `limit='30/minute'` on that forward. That this was the cause is the best
reading of the run, not a measurement: from the LAN I am exempt from the penalty, so the next CI
run is what confirms it.

MEASURED on 29/09/2026 against the LAN address instead of the anchor, to prove the mechanics
before the first CI run: 41s for the full sweep, `2222` reported as `OpenSSH_10.5, clean, auth:
keyboard-interactive,publickey`, and every LAN-only port (Jellyfin, Sunshine, Dropbox) flagged as
not declared, which is exactly what the WAN must never show.
