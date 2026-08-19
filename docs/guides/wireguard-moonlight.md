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

## Measured on 19/08/2026, from the peer `pc-trampo`

Steps 1 and 2 finally ran for real, this time from the HOST toward the peer, which covers the same
tunnel plus the LAN leg:

- **Path MTU: exactly 1420.** `ping -M do -s 1392 10.10.10.4` passes and `-s 1393` fails, so the
  interface number the guide predicted is also the end-to-end number: nothing between the router
  and the Sunshine host narrows it further.
- **RTT 35.7 ms** average over 40 packets (min 31.2, max 77.9, mdev 8.1), with **0% loss**.
- For contrast, the DIRECT path from that same machine measured 1.67% loss with RTT spiking from 20
  to 312 ms, which is the number that justified `fec_percentage = 30`.

Pinging the PEER is a valid test from either end, because the packet has to cross the tunnel to be
answered. The guide's warning about a ~0.3 ms result applies to pinging the ROUTER from home, which
measures the cable instead.

## The Windows client, and the kill-switch that carves `AllowedIPs`

`pc-trampo` runs the official Windows client, and there the routing tricks of `wg-quick` do not
exist: no `PostUp`, and no `ip rule ... suppress_prefixlength`.

**A literal `0.0.0.0/0` in `AllowedIPs` turns on the app's kill-switch**, which blocks every packet
that is not going through the tunnel, the LOCAL network included. On a machine whose reason to keep
local access is the FAI network, that is the opposite of what is wanted. The app looks for a route
with prefix length 0, so a list that covers everything WITHOUT ever writing `/0` gets full-tunnel
routing with no kill-switch.

So `AllowedIPs` is `0.0.0.0/0` MINUS the ranges that must stay local, expanded into the 62 blocks
that survive. The exclusion list, and where each entry comes from:

| Excluded | Why |
| --- | --- |
| `192.168.90.0/24`, `.100`, `.110`, `.130`, `.223` | The FAI ranges already listed in `system/net/fai-gateway.nix` |
| `200.136.209.128/25` | FAI too, and it contains the workstation `.229` and the DNS `.247`/`.252` |
| `200.136.204.0/23` | The work PC's own subnet, from the RDAP query of 19/08/2026 |

Regenerate the list instead of hand editing it, because 62 blocks written by hand is a silent bug
waiting to happen:

```sh
python3 -c '
import ipaddress as ip
keep=[ip.ip_network("0.0.0.0/0")]
for n in map(ip.ip_network,["192.168.90.0/24","192.168.100.0/24","192.168.110.0/24",
        "192.168.130.0/24","192.168.223.0/24","200.136.209.128/25","200.136.204.0/23"]):
    keep=[x for k in keep for x in (k.address_exclude(n) if k.overlaps(n) else [k])]
print(", ".join(map(str,ip.collapse_addresses(keep))))'
```

**Check the result before pasting it**: `192.168.1.0/24` and `10.10.10.0/24` have to be INSIDE the
list (home LAN and the tunnel itself), and each excluded range has to be absent from every block.

The client's `DNS` is `10.10.10.1`, the router, which is what keeps `fai2008.ufscar.br` resolving
through the forward that already exists there, and gives the house's adblock for free. That choice
is what forced the endpoint to stop being `ssh.v1cferr.dev`: see the split-DNS trap in
[`../notes/network/network.md`](../notes/network/network.md).

## 4. What to do with the result

Today `packet_size = 1024` in `system/services/sunshine.nix`. It was calibrated for the
**1280** MTU of the old `tailscale0`, leaving 256 bytes of headroom. That MTU no longer exists
anywhere, and with 1420 MEASURED the arithmetic is no longer a guess:

| Candidate | Where it comes from |
| --- | --- |
| **1136** | The same proportion that worked, 1024/1280 = 80% of 1420 |
| **1164** | The same ABSOLUTE headroom, 1420 minus 256 |
| 1312 | Sunshine's own 1392-for-1500 default, 108 bytes of headroom. Do not start here |

The tunnel is the SMALLER of the two paths (1420 against the direct one's 1492), so a value
calibrated for it is safe on both, and retiring path 2 would not raise this ceiling.

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
