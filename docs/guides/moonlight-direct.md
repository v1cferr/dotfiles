# Test: Moonlight direct, with no VPN, from UFSCar

**Where:** UFSCar, on the FAI notebook, **with no WireGuard and no VPN active at all**.
**Why:** the direct path (`docs/history/2026/08-august.md` does not cover it, it was opened
on 10/08/2026) trades the tunnel for a restricted port forward. TCP is proven; UDP is not.
This protocol separates "UDP does not get through" from "a video problem", which produce
almost identical symptoms.

**The VPN has to be OFF.** With the tunnel up the test lies: Moonlight finds the host
through `10.10.10.1` and you measure the old path thinking you measured the new one. It is
variant 2 of the method trap recorded on 08/08, a test that looks external and is not.

## 0. Prerequisites

- Host: `system/services/sunshine.nix` applied (`nixos-rebuild switch`).
- Router: `scripts/router-moonlight-forward.sh` executed.

## 1. Is the `src_ip` holding? (a SECURITY test, not a reachability one)

**This step has to FAIL in order to pass.** The redirects are restricted to the UFSCar
blocks, so any external vantage point must be refused. If it connects, the `src_ip` is not
applied and Sunshine is open to the planet.

And from inside the LAN this test is worthless: the ISP does hairpin and the port
"opens" every time. From outside only.

```sh
curl -s "https://check-host.net/check-tcp?host=177.52.84.188%3A47984&max_nodes=3" \
  -H "Accept: application/json"
# grab the request_id, wait ~10s, then:
curl -s "https://check-host.net/check-result/<request_id>" -H "Accept: application/json"
```

- `{"error": "Connection refused"}` on ALL nodes → correct, the `src_ip` holds
- `{"address": "177.52.84.188", "time": …}` on any node → **stop**: the restriction did
  not take. Check `uci show firewall | grep -i moonlight` on the router

**The counter-test that gives the one above any meaning:** run the same thing against
**2222**, which is unrestricted. It MUST connect (measured on 10/08/2026: Austria, Canada
and Iran, all OK). Without that control, "refused" on both would be indistinguishable from
"the link went down", and you would have read an internet outage as a security success.

**A third counter-test:** **47990**. Refused, always, from anywhere, because it is the
admin panel and it is not forwarded. See the `origin_web_ui_allowed` warning in
`sunshine.nix`.

A consequence of the design: **this method cannot confirm that the port opened for UFSCar**,
only step 2, from inside it, does that.

## 2. Does it arrive from UFSCar? (on the notebook, with no VPN)

```sh
nc -vz ssh.v1cferr.dev 47984 47989 48010
```

If TCP fails here after passing step 1, the block belongs to the UFSCar network, not to
yours. Recorded on 08/08: **the FAI network drops the SYN-ACK**. The SYN arrives home, the
host answers, and the final ACK never comes back. If the notebook is on the FAI segment
(`200.136.192.0/21`) instead of the campus one (`200.133.224.0/20`), that is the expected
case, and the answer is to use the tunnel.

## 2b. Pairing a NEW client does not work over this path

The FAI notebook (`"fai pc"`, paired on 27/07/2026) gets in directly: an already paired
client uses the certificate it has, and that is pure 47984. **A new client is another
story**: the PIN is typed into the web UI, which is **47990**, and that one is not forwarded
on purpose.

Do not force 47990 open to the world. The ways out:

1. **Pair over the WireGuard tunnel**, once, and then use the direct path forever. It is the
   simplest one and it touches nothing.
2. An SSH tunnel: `ssh -L 47990:localhost:47990 v1cferr@ssh.v1cferr.dev -p 2222` and open
   `https://localhost:47990`.
   **Not verified, and there is a concrete reason to be suspicious:** the
   `csrf_allowed_origins` in `sunshine.nix` lists only `https://192.168.1.10:47990`, and
   over that tunnel the browser sends `Origin: https://localhost:47990`. Sending the PIN is
   a POST, so CSRF applies. If saving errors out, that is why, and the fix is adding that
   origin to the option, not opening the port.

## 3. UDP, the question this test exists to answer

There is no conclusive way to test UDP with `nc -z` (no answer is not the same as blocked).
The real test is streaming. Pair and run for **5 minutes**, watching:

| Symptom | Reading |
| --- | --- |
| Does not pair | TCP, go back to step 2 |
| Pairs, lists the apps, and the screen **never appears** | **UDP blocked.** This is the suspected case |
| Opens and freezes within seconds, with no encoder error in the journal | **UDP blocked or intermittent** |
| Opens and drops at ~4 s, repeatedly | MTU, see `wireguard-moonlight.md` |
| Runs for 5 min | it works |

At home afterwards: `moonlight-stats 1`.

**"It pairs but does not stream" is the failure mode to memorize.** Pairing and the app
list are TCP (47989/47984); video, audio and control are UDP (47998-48000). A session that
opens and freezes looks like a capture or encoder bug, and on this path it almost never is.
Before touching anything in Sunshine, rule UDP out.

## 4. If UDP is blocked

There is no fix on this side: what drops it is the UFSCar firewall. The ways out, in order
of preference:

1. **Go back to the tunnel**, which is still up, and it stuffs everything inside 51820/UDP,
   which is PROVEN to cross that network (measured on 08/08). That is the reason not to tear
   it down.
2. Ask CoTI/SIn (`sin-citi@ufscar.br`) to open it, since the ports are fixed and
   documentable, but the timeline is institutional.

## 5. Result, 10/08/2026

The direct path is NOT a better route: it is the same path without encapsulation (the
WireGuard endpoint is the router itself). What it gains is MTU (1492 from PPPoE against
~1420 through the tunnel) and not needing a VPN client.

**UDP gets through.** It was the only unknown and it is answered, not by inference but by
the router's DNAT counter: `Moonlight-Stream-Campus → packets 3`. That counter only counts
the FIRST packet of each new flow (after that conntrack bypasses dstnat), so 3 is exactly
the three expected flows, video 47998 + audio 47999 + control 48000. Keep the method: it is
the cheapest way to prove a UDP flow without instrumenting the client.

Measured from home to `200.133.233.101`, 100 packets of 1 KB:

| Metric | Value |
| --- | --- |
| Mean RTT | 35.5 ms (min 34.7 / max 38.1) |
| Loss | **0%** |
| Jitter (mdev) | 0.54 ms |
| Longest session | 21m58s, followed by 9 min+ |
| Throughput in desktop use | ~3 Mbps ↑ |

Against the jul/2026 measurement over the FAI path (**1.67% loss, RTT 20 to 312 ms**), it is
another world. But it is not a clean comparison: a different source segment (campus vs
FAI) and ICMP is deprioritized by switches. It counts as a strong indication, not as proof
about the video flow. For that, use the Moonlight overlay (`Ctrl+Alt+Shift+S`).

**Latency: noise, as predicted.** The 35 ms are the RTT of the physical path, which the
tunnel travelled all the same. There was no routing gain because there was no route to gain.

The route, with the owners identified through RDAP: four autonomous systems, none of them an
intermediate server (they all forward packets, none terminates the connection):

```text
router → Algar Telecom (AS16735) → IX.br/NIC.br (AS26162)
       → RNP (AS1916) → UFSCar (AS52888) → notebook
```

IX.br and RNP cannot be removed: UFSCar's internet comes from RNP.

### What the real session revealed, and was not predicted here

- **`ping_timeout = 20000` absorbed an 18.9 s hole** at 11:47 without dropping the session.
  The proof is that the hypridle guard did not cycle (a single `Stopped` at 11:25, no
  `Started` at 11:47), so the prep-cmd `undo` never ran. A reusable method: the guard is a
  more reliable end-of-session detector than the `CLIENT DISCONNECTED` line, which shows up
  both on a real drop and on an absorbed reconnect.
  Both drops that day (18.9 s and 104 s) were me reconnecting, which I confirmed. They
  are not evidence of an unstable route, since every test came back with 0% loss.
- **HEVC: it negotiates, but it does not serve on this client.** Turned on at 14:43
  (`hevc_vaapi`, Rec. 709) and turned off at 14:57 because in practice it was "way too
  buggy". H.264 is the final choice for this machine, and it is DELIBERATE, not the default
  nobody reviewed.
  That contradicts the 03/08 note in `sunshine.nix` FOR THIS CLIENT, and it is the record
  that keeps the next person from repeating it: there it says that turning HEVC/AV1 on "is
  worth more than any host tweak". It is, where the decode is any good. Here it negotiated
  cleanly in the journal and delivered a bad image, which is the worst possible case to
  diagnose, because on the host side EVERYTHING looks right.
- `Video encryption enabled` on both sessions: WAN mode came on by itself, with nothing
  configured.
