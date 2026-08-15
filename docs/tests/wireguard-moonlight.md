# Test: tunnel MTU + Moonlight over WireGuard

**Where:** UFSCar, on the **FAI notebook**, with WireGuard connected.
**Why:** from home it is impossible, because there is no WireGuard interface on this machine
(the tunnel terminates at the ROUTER), so any ping to `10.10.10.1` goes out over the cable
and measures the LAN, not the tunnel. The sign of an invalid test is ~0.3 ms of latency.

A reusable protocol: it applies every time the MTU or `packet_size` changes, or the client
changes.

## 1. The tunnel MTU (the direct answer)

On the notebook, with the VPN up:

```sh
ip link show | grep -A1 -i wg
```

The `mtu N` there is the answer. WireGuard usually sits at **1420**.

## 2. Confirm end to end (what matters)

The number above belongs to the interface; what decides is the WHOLE path: tunnel, router,
LAN, all the way to the Sunshine host:

```sh
ping -M do -s 1372 192.168.1.10
```

- it passed, so go up: `1392`, `1400`, `1412`
- it failed with *"message too long"*, so go down

**The largest `-s` that passes, plus 28** (IP+UDP headers) = the real path MTU.

Write the number down. A latency of several milliseconds confirms the test is valid; 0.3 ms
means you are not going through the tunnel.

## 3. Moonlight for real

Pair and stream from the notebook. Watch for:

- does the session go past 2 minutes?
- is there a disconnect at ~4 s? That is the classic symptom of a packet blowing past the
  MTU

Afterwards, at home: `moonlight-stats 1` shows the duration of the day's sessions.

## 4. What to do with the result

Today `packet_size = 1024` in `system/services/sunshine.nix`. It was calibrated for the
**1280** MTU of the old `tailscale0`, leaving 256 bytes of headroom. With WireGuard at
~1420 there is probably room to spare, and a bigger packet means less overhead per frame.

**Do not jump straight to the ceiling.** Blowing past the MTU makes WireGuard drop
SILENTLY, with no ICMP and no log. The host streams normally, the client receives half of
it, fails to reassemble the frame and drops in ~4 s. That was exactly the bug of
29/07/2026, and it cost a long debug precisely because it raised no error anywhere.

Go up with the same proportional headroom that already worked, and validate with a real
session before committing.

## Context

- The `fai-workstation` **is** a peer (`10.10.10.5/32`), but it is an Ubuntu server with no
  graphical interface, so it serves step 2, not step 3.
- Existing peers: `notebook` (`.2`), `celular` (`.3`), `fai-workstation` (`.5`).
- Measured on 08/08/2026: UDP 51820 from the FAI network **does reach** the router (the
  `Allow-WireGuard` counter went from 0 to 3). The path exists.
