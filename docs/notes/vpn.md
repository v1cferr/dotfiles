# vpn

Module: [`system/net/vpn.nix`](../../system/net/vpn.nix)

The FAI and UFSCar VPNs, declarative and on demand. They do not come up at boot: the `vpn` CLI
and the SUPER+N / SUPER+SHIFT+N / SUPER+CTRL+N binds turn them on and off. They are system
services, because a VPN needs tun and routes.

| VPN | Protocol | Client |
| --- | --- | --- |
| UFSCar | GlobalProtect (Palo Alto) | `openconnect --protocol=gp`, FOSS, in nixpkgs |
| FAI | SonicWall SSL VPN | nxBender ([`pkgs/nxbender.nix`](../../pkgs/nxbender.nix)), replacing the proprietary netExtender |

If nxBender ever stops connecting, the fallback is packaging netExtender.

Passwords come from sops: openconnect reads on STDIN (so it stays out of `ps`), and nxBender reads
a config rendered by `sops.templates` into `/run/secrets/rendered`, root-only, never in the store
and never in git. The FAI fingerprint in there belongs to their SELF-SIGNED cert, which is public
and not a secret; without it nxBender refuses the SSL. If FAI swaps the certificate:

```sh
openssl s_client -connect 200.133.233.101:4433 | openssl x509 -noout -fingerprint -sha1
# nxBender wants lowercase sha1 with ':'
```

`--authgroup` on the UFSCar side picks the gateway (the portal offers 5). Without it openconnect
asks interactively and the service dies, because stdin holds only the password, so it gets EOF.

## `is-active` LIES, and it cost three separate bugs in this one file

This is the single most important thing on this page. During a crash loop the unit is
`activating` (SubState=auto-restart), and:

- `systemctl is-active --quiet` exits NON-ZERO while `activating`;
- `systemctl is-active` (no `--quiet`) reports `active` during each attempt of the loop.

So the same command lies in both directions depending on how you ask. The three bites:

1. **The pill stayed green for nothing.** With the FAI portal down, nxBender crash-loops and
   systemd reports active during each ~2min attempt, with zero ppp0. "Connected" now means the
   unit is active AND the tunnel actually exists.
2. **The diagnosis announced the opposite of the truth** (12/08/2026). The gate used
   `is-active --quiet`, so in a crash loop it said "unit stopped, no attempt in progress" while
   nxBender had been trying for 18 hours. It sent me looking for a network problem in a credential
   failure, and it cost the whole session. The gate now reads `ActiveState`, which separates the
   three cases that matter: `inactive` (nobody asked), `activating` (trying right now) and
   `failed` (tried and gave up); the last two MUST reach the classifier.
3. **The self-healer was dead code.** Same mistake, third appearance: it never acted during the
   login storm, at the exact minute it was needed.

`fai_conn`/`ufscar_conn` keep `is-active` on purpose, because there "connected" really does
require the unit to be active.

## Exponential backoff with no ceiling

The previous ceiling (6 attempts / 10 min) had a hole. When the SonicWall ACCEPTS the connection
and drops it in ~24s (SIGHUP), each cycle lasts ~34s, so 6 attempts burned in ~3.5 min and systemd
marked start-limit-hit, leaving the unit PERMANENTLY `failed`. That is worse than the original
bug: not even `vpn connect fai` would come up anymore without a manual `systemctl reset-failed`.

Now it is 10s to 300s progressively and it never gives up. A wrong password means ~12 attempts/h
in the worst case, gentle enough not to trip an account lockout at the portal.

## Two watchdogs, for two different silent failures

**The hang.** nxBender calls the portal WITHOUT a timeout (visible in the traceback:
`connect timeout=None`). When the SonicWall accepts the TCP but does NOT answer the session
request, the process sleeps forever: the unit stays `active/running`, with not ONE log line and no
tunnel, and `Restart=always` never acts, because it only reacts to a process that EXITS. Measured
on 31/07: **11 min hung** with the connection in ESTAB and Recv-Q and Send-Q at zero; a
`systemctl restart` connected in 10s. It is the same shape as the Sunshine HTTPS handler hang
(see [`sunshine.md`](sunshine.md)): active, exit 0, invisible by definition.

The healer only acts when all THREE conditions hold: the unit is active (somebody asked to
connect), the tunnel is absent, and it has been active longer than the grace. The grace exists
because connecting legitimately takes ~10 to 30s; without it the watchdog would kill the
connection in progress and become the problem itself.

**The unrecoverable error.** `Restart=always` is right for the common case (the FAI portal
flapping) and WRONG for a credential: an expired password does not improve with retries, and each
cycle is one failed login at the SonicWall. During the 11-12/08/2026 episode that was **59 failed
logins in ~18h**, with a real risk of locking the account. So the policy INVERTS: if the log
signature is a credential one, it STOPS the unit instead of restarting. Only I can fix it, by
changing the password in AD, and until then insisting only accumulates damage.

The log window is 10 min, so the evidence comes from the attempt in progress and not from
yesterday's episode, which would otherwise stop a healthy VPN.

## The diagnosis, and why its classification is measured

A connection failure used to be SILENT: you clicked Connect, nothing happened, and from this side
it looked like a problem with the personal machine. The goal is not dumping logs, it is having the
notification SAY WHOSE FAULT IT IS, because that is what changes what you do next: wait for FAI to
come back, or touch your own network or password.

**Why a watcher and not systemd's `OnFailure=`**: these units have `Restart=always` with
`startLimitIntervalSec=0`, so they NEVER enter `failed`. They stay in an eternal crash loop and an
`OnFailure` would never fire. The trigger has to be time: 45s after the connection request, if
there is no tunnel, diagnose and warn once.

The signatures come from this machine's journal over 2 days, not from imagination: a ConnectTimeout
on `/cgi-bin/userLogin` (the portal is down) is the most common case at **152 occurrences**,
`Connection reset by peer` at **27**, and `Modem hangup` / `Peer not responding` /
`No response to N echo-requests` meaning the tunnel came up and dropped.

**The order of the tests matters**: internet from here, then the portal being reachable, and only
then the log. Without that order, a "timeout" in the log reads as FAI's fault even with your own
network down.

**The expired password comes FIRST** on purpose: it is the only case on the list where retrying
NEVER works. Without that case the failure fell into "unclassified cause", and the raw evidence
misleads: the SonicWall phrase ("please check TLS, server writable or other config") looks like a
configuration error on OUR side, when it actually says the APPLIANCE cannot write the password
change into AD. Measured on 12/08: the web portal refuses the same way (`E_UNAUTHORIZED` /
"Password expired.") and does not even offer a change form, so no client solves it. What worked
was Ctrl+Alt+Del on a domain machine.

Two smaller things learned there: the log window is 15 min so the evidence is from the CURRENT
attempt, and `-o cat` asks journalctl for the bare message instead of stripping the prefix
afterwards with `sed 's/.*nixos-sandisk //'`, which silently became a no-op the day the hostname
changed. Asking the tool for the right format cannot age; cutting by name can.

## status-json and stats-json are separate on purpose

`status-json` answers "is there a tunnel?" every 5s and is what paints the pill. `stats-json`
answers "with what?", meaning interface, IP, MTU, uptime, session bytes and which host serves as
the probe target; the bar only calls it when there is a tunnel (every 20s in the background, every
3s with the panel open).

**Latency does not come from either.** What measures it is the bar, with a CONTINUOUS ping of 1
packet/s. The division is deliberate: discovering who answers inside the tunnel is shell work
(sweeping routes, testing candidates, memorizing) while measuring is the work of whoever watches
all the time. The previous version measured here in bursts of 3 packets and the number came out
pretty and false; the measurement that proved it is in [`quickshell.md`](quickshell.md).

## The probe target

Tunnel latency needs somebody who answers INSIDE it, and the obvious candidate does NOT work: the
FAI ppp peer is `192.0.2.1`, TEST-NET-1, a facade address of the SonicWall, and it ignores ICMP
(measured 14/08/2026: 100% loss). What answers is `200.136.209.236` (fai.ufscar.br). It is a
public IP, but the `200.136.209.128/25` route goes out through ppp0, so the ping measures the
TUNNEL (31ms, 0%).

Not the workstation host, for two reasons: `my.fai.workstation` is a home-manager option and a
system module cannot read one (rule 11), and an institutional server goes down less often than a
workstation.

UFSCar enters with NO fixed candidate. I never measured an internal host of theirs with the tunnel
up, and guessing an address would produce a wrong number, which is worse than a missing one. It
falls back to the routes; if a target ever proves itself, that is where it goes.

**`-I <iface>` is not a detail**: it pins the packet to the tunnel (SO_BINDTODEVICE). Without it a
target that stopped being routed through the VPN would go out over the home internet and the panel
would show a GREAT latency that is not the tunnel's. With the bind that case becomes silence, and
"no probe" is an honest answer while "8ms" would be a lie.

The target is memorized (the cache key is iface plus IP, so a new tunnel means a new probe). A
live target holds for the whole session; "not found" is reevaluated every 5 min, otherwise a
target that was down at the instant of connection would condemn the panel to "no probe" until
disconnecting.

## Ownership details

The connection watcher is a DECLARED UNIT and not a background subshell (rule 15). A loose `&` in
the CLI would be parented to Quickshell, which invokes it through `Process`, and would disappear
on a shell restart at exactly the minute it should warn. It is a `@<id>` template because the two
VPNs have different portals and different symptoms.

Both watchers are USER units, because what delivers the notification is Quickshell, in the
session, and because the polkit rule already lets this user restart the `vpn-*` units, so no root
is needed. Under autologin the session is always up; if that ever changes, the watchdog stops
running without a session, and that is the known limitation.

The `~/FAI-workstation` rclone mount comes up and goes down WITH the FAI VPN
([`home/services/fai-workstation-mount.nix`](../../home/services/fai-workstation-mount.nix)),
started with `--no-block` so it does not wait on the tunnel; the service retries until the host is
reachable.

## Removed on 30/07: the `menu` subcommand

It opened a loose rofi in the middle of the screen. The UI is now a popover ANCHORED to the bar
(`quickshell/bar/VpnPopover.qml`), in the shell's theme. It is not only cosmetic: the rofi menu
built its labels with `systemctl is-active`, so it said "Disconnect" during the nxBender crash
loop with no tunnel existing. The popover reads `status-json`, which checks the real tunnel.
