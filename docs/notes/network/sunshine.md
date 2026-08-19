# sunshine

Module: [`system/services/sunshine.nix`](../../../system/services/sunshine.nix)

Screen streaming for Moonlight, over Hyprland/Wayland. It captures through wlr-screencopy and
encodes on the Arc B580's AV1/HEVC encoder (VA-API). It replaced Tailscale as the remote access
path on 08/08/2026.

## Two ways in, and neither opens a port on every interface

`openFirewall = false` holds for both.

1. **The router's WireGuard**, through the `10.10.10.0/24` source rule in
   [`network.md`](network.md).
2. **The internet, directly**, restricted to the UFSCar blocks: the rules at the end of the module
   plus the `Moonlight-*` redirects on the router.

Path 2 exists because the FAI notebook already runs nxBender plus openconnect, and a third VPN
client there is a routing conflict waiting to happen.

**Path 2 is NOT "more direct" than path 1**, and that was the premise that motivated it. The
WireGuard endpoint is the home router ITSELF, so both travel UFSCar to internet to the house.
There is no relay (that was a Tailscale risk, and Tailscale is gone). What path 2 actually gains is
MTU, 1492 from PPPoE against 1420 through the tunnel, and what it gains in latency is noise. Do
not rewrite this as a routing gain.

**Encryption is not downgraded.** Sunshine classifies the client by IP: through the tunnel it
arrives as `10.10.10.x` = LAN, so `lan_encryption_mode = 0` (the tunnel already encrypts); over
the internet it arrives public = WAN, so `wan_encryption_mode = 1`, the default, stays ON. Do not
touch those two: they are what keeps path 2 from streaming in the clear.

## The port list is derived, because the blogs are wrong

The offsets come from the build in use (2026.516.143833), read in
`assets/web/assets/config-*.js`: tcp `port-5`, `port`, `port+1`, `port+21`, and udp `port+9`
through `port+11`.

Almost every list on the internet includes a UDP 48002 ("mic") that **does not exist** in this
version. There are three UDP ports, not four. Check the js in the store when updating.

The 8 firewall rules (sources times ports) are GENERATED and not written by hand, because the stop
list has to match the start list EXACTLY: a rule that does not match is not removed on reload and
stacks a duplicate on every rebuild. Writing 16 mirrored lines by hand is precisely how you leave
one behind.

## Why the source list is a literal, and what mirrors it

The UFSCar blocks were confirmed on registro.br on 10/08/2026, both under the same CNPJ. It is a
literal and not an option because rule 11 asks for 2+ consumers and here there is one. Two of them
were confirmed, not all of them, which is the subject of the correction at the end of this section.

**But there is a mirror to keep in sync by hand**: the `src_ip` of the `Moonlight-*` redirects in
`router/uci/firewall.conf`. If the two lists diverge, the router forwards and the host drops, and
the symptom is "Moonlight does not connect", indistinguishable from everything else.

**Do NOT swap it for `0.0.0.0/0`.** The house is NOT behind CGNAT (measured 10/08/2026: port 2222
answers from Austria, Canada and Iran), so that literally means the planet. What these ports hand
to whoever reaches them is `/serverinfo` with NO authentication: hostname, GPU, app list and
whether there is an active session. Pairing still needs the PIN typed on the host; inventorying the
machine needs nothing.

### The list is INCOMPLETE, measured 19/08/2026

UFSCar does not have two blocks, it has at least four, all `REASSIGNED` under the same CNPJ
45358058000140 (Coordenadoria de Infraestrutura de TI). Queried over RDAP at `rdap.registro.br`:

| Block | Declared here? | Seen in use by |
| --- | --- | --- |
| `200.133.224.0/20` | yes | 200.133.233.101, the client of the session that WORKED on 19/08 |
| `200.136.192.0/21` | yes | nothing, ever. See below |
| `200.136.204.0/23` | **no** | 200.136.205.252, the work PC on 19/08 |
| `200.136.208.0/20` | **no** | 200.136.209.229, the FAI workstation (`ssh workstation`) |

So a Moonlight client on the last two cannot connect AT ALL, and nothing about the symptom says so:
the router does not match the `src_ip` of any `Moonlight-*` redirect and drops the packet before the
DNAT, which leaves NO trace on this host. Measured on 19/08 while the failure was live: no conntrack
entry, no refused packet in the kernel log, and not one connection attempt in Sunshine's own log.
The `/serverinfo` on 47989 answered 200 to loopback the whole time.

**The list was deliberately NOT widened.** Doing it means editing two places that have to stay in
sync, and it hands `/serverinfo` with no authentication to more of UFSCar, which is a call to make
on purpose and not while chasing a symptom. It was never needed: on the same day the work PC became
the WireGuard peer `pc-trampo` (`10.10.10.4`) and reaches Sunshine through path 1, where the source
rules do not apply at all. That also makes **retiring path 2** a live option, which would take
`/serverinfo` off the internet entirely. It would NOT unpin `packet_size`: the binding constraint is
the SMALLER path, and that is the tunnel's 1420, measured on 19/08 in
[`guides/wireguard-moonlight.md`](../../guides/wireguard-moonlight.md).

### The SYN-ACK theory is DEAD, measured 19/08/2026

What this file used to state as measured: the FAI network drops the SYN-ACK on the way back, the SYN
arrives, the host answers, the router's conntrack sits in `SYN_RECV` and the final ACK never comes,
so a connection from the /21 may not complete.

The problem with it is the table above. **No FAI address ever observed falls inside the declared
/21**, so for the machines actually used the rule never matched in the first place, and from the
client the two causes are IDENTICAL: a SYN goes out and nothing comes back. The `SYN_RECV`
observation is the one piece that does not fit the simpler explanation, and it was not re-checked.

**It came out as outcome 2: our list.** There is no `tcpdump` on the router (6 MB of flash, 1.3 MB
free in `/overlay`, and nothing gets installed for one measurement), so the instrument was a
TEMPORARY `nft` counter on `input_wan` matching `ip saddr <work PC> tcp dport 47989`, with no
verdict, removed right after. It counted **11 packets** while the client retried.

So the SYN ARRIVES. It matches no `Moonlight-*` `src_ip`, falls through to `reject_from_wan` and
gets `reject with tcp reset`. Their firewall on the way out was never the problem.

The DNAT counters say the same thing from the other side, and they are free to read:

| Rule | Packets |
| --- | --- |
| `Moonlight-*-Campus`, `200.133.224.0/20` | 5, 4, 7 and 3, the session of that morning |
| `Moonlight-*-FAI`, `200.136.192.0/21` | 0, 0, 0, 0 |

**One loose end, stated instead of hidden.** `handle_reject` sends a TCP reset, so `nc` should have
failed FAST with "connection refused", and it hung instead. Something eats the return packet, which
is the same SHAPE as the old theory even though the packet is a reset and not a SYN-ACK. The return
path was never instrumented, and it stopped mattering the same day: the machine that produced the
symptom now comes in through the tunnel (`10.10.10.4`), where none of this applies.

The /20 (campus) DOES get through, proven twice: the SSH session of 10/08/2026 and the Moonlight
session of 19/08/2026, whose client was 200.133.233.101.

## The black screen was DPMS, not a codec

A long debug in jul/2026. "Black screen in Moonlight" was wlr capturing the monitor while
DPMS-OFF, and NOT a version or encoder regression. Capture works as long as the monitor is ON
during the stream, which is why the `streamBegin` guard exists.

`capture=kms` would be an alternative, but kmsgrab does NOT enumerate on the `xe` driver
(Battlemage): "Unable to find display", and the service does not even stream.

**Careful**: toggling DPMS WITH capture and encoding active caused a GPU engine reset (xe RCS),
which is why the guard wakes the screen BEFORE the stream, in the prep-cmd, never in the middle.

**Force `capture=wlr`.** Without it Sunshine PROBES the `portalgrab` backend at startup, and on
Hyprland that probe fires `hyprland-share-picker`, which does not render (a missing Qt plugin) and
HANGS Sunshine, so it never opens the ports. Video is wlr, input is uinput through the
`/dev/uinput` uaccess ACL, both with no portal.

**Pin WHICH monitor.** Without it wlgrab takes the FIRST in the enumeration, and the TV enumerates
before the LG, so Moonlight opened on the SECONDARY monitor. Measured in the log:
`Monitor 0 is HDMI-A-3 / Monitor 1 is DP-2` then `Selected monitor [... LG TV]`. It is not the
client's choice: Moonlight gets what the host sends. It matches by connector NAME and not by index,
because the index depends on enumeration order, which is exactly what went wrong.

## The idle guard, and why it needs a watchdog

The capture is of the PHYSICAL monitor, so idle must not turn the screen off. `dpms-off` was
removed for that reason (black screen plus a GPU engine reset on xe). What is left is the LOCK
after 5 min, which mid-stream would lock the remote session, so the guard PAUSES hypridle while the
stream runs and turns it back on at disconnect.

**The `undo` is not a guarantee.** Measured on 10/08/2026: a client disappeared with no clean
teardown at ~14:57, Sunshine never closed the session, the `undo` never ran, and hypridle stayed
stopped for 6h. `ping_timeout` does not cover this: it drops the STREAM, not Sunshine's session
bookkeeping. And while hypridle is stopped the machine never locks by itself.

**The signal has to be reality, not Sunshine's bookkeeping.** The obvious path would be
`/serverinfo`, and that is precisely what lies: at 17:30 that day it still said
`SUNSHINE_SERVER_BUSY` with the client dead for 2h30. A watchdog keyed on it would never fire.

What did not lie in the same measurement: **the sockets**. With the ghost session "active",
Sunshine had ZERO UDP sockets on the video ports; it creates them per session and closes them at
the end. So `bound` means a real stream.

Honest about the evidence: the NEGATIVE side was measured (no stream implies no socket); the
positive one is a strong inference, not an observation. Check on the next stream with
`ss -uan | grep 4799` before treating it as fact.

Since 19/08/2026 that test is one script, `sunshine-stream-active`, because a second consumer showed
up (the ghost reaper below) and the `ss` filters were worth writing once instead of twice.

**The second consumer changes the stakes of the measurement still pending.** The guard only turns
hypridle back on, so a wrong answer costs a lock. The reaper RESTARTS Sunshine, so a live stream
with no bound socket would cost a dropped session, and that failure mode is precisely the negation
of the inference nobody has confirmed yet. That is why the reaper does not trust the sockets on the
first look and waits.

The guard writes a mark in `XDG_RUNTIME_DIR` saying the hypridle pause belongs to IT and not to a
human, because the bar's pill also stops hypridle on purpose, and without the mark the watchdog
would undo that manual toggle within 5 min.

## Three shell traps this file paid for

**`set -o pipefail` plus `grep -q` inverts the result.** `grep -q` exits on the 1st match, the
producer dies of SIGPIPE, and the pipeline returns an ERROR despite having matched. In
`sunshine-health` that read a successful TLS handshake as a failure, and the timer would have
restarted Sunshine every 2 min forever. The fix is capturing into a variable plus a `case`, with no
pipe at all. The same trap appears in [`vpn.md`](vpn.md).

**`ss` filters itself**, for the same reason. And it is `not dst X`, never `dst != X`: the second
looks natural and the parser rejects it with `bison bellows (syntax error)`. Tested 10/08/2026.

**A `runtimeInputs` missing a binary is a LATENT bug, not a build error.**
`writeShellApplication` PREPENDS its inputs and then appends the inherited PATH, so a command it
does not declare still resolves when you run the script by hand, because an interactive shell has
`/run/current-system/sw/bin`. Under systemd it does not: a USER unit gets a fixed PATH of
coreutils, findutils, gnugrep, gnused and systemd, and nothing else. `hypridle-guard` used `awk`
without declaring `gawk`, so it exited **127** on the `/proc/uptime` line every 5 min from 10/08 to
19/08/2026: the watchdog was dead for those 9 days while testing by hand kept saying it worked.
Measured on 19/08: `ExecMainStatus=127` with `Result=exit-code`.

`sunshine-health` does a real TLS handshake on 47984, because `-brief` prints `Protocol version:`
only when the handshake COMPLETES. An accepted TCP is not enough, which was exactly the hung state
of 29/07. It targets 127.0.0.1, so it does not depend on the VPN.

## `packet_size` is locked at 1024, and that is a constraint now

Sunshine's default is 1392, calibrated for MTU 1500. In a tunnel it overflows and WireGuard drops
it SILENTLY (no ICMP, no log): the host streams normally, the client receives half, fails to
reassemble the frame and disconnects in ~4 s. That is what happened on 29/07 with tailscale0
(MTU 1280).

Since 10/08/2026 this is no longer conservatism. The value is GLOBAL, one for every client, and
there are now two paths with DIFFERENT MTU: the tunnel (~1420) and the direct one from UFSCar
(1492). Whoever calibrates for the direct path breaks the tunnel one, in the worst way this file
documents. **The useful ceiling is the smaller path's, always.**

It only makes sense to raise it if the tunnel path is RETIRED, and then the number comes from
[`guides/wireguard-moonlight.md`](../../guides/wireguard-moonlight.md), not from a guess.

## Two more settings that look wrong and are not

**`origin_web_ui_allowed = wan`** is kept at the more permissive value on purpose, because what
decides the reach is the firewall, not Sunshine. Tightening it gains nothing and risks breaking the
web UI silently, since the stream does not use CSRF, so the symptom only shows up when opening the
panel.

**This only stays safe while 47990 is not forwarded.** Until 10/08/2026 the claim was "only the
WireGuard range reaches this port", and it stopped being true the day direct access landed. 47990
was left out of both lists precisely because this value is `wan`; forwarding it would publish the
admin panel with no gate at all.

**The CSRF origin is a snapshot.** It was already wrong once, between the cutover (01/08) and
02/08/2026, and nobody noticed, because only the web UI breaks. Back then it pointed at the
tailnet, whose IP changed on every rejoin. Now it is this machine's LAN IP, which is where the
WireGuard peer arrives. An IP cannot be derived at build time, so it is worth guaranteeing a static
lease on the router: without one, changing IP breaks the panel again and you only find out when you
try to open it.

## moonlight-stats

"It drops all the time" is not measurable, and the Sunshine log only says `CLIENT DISCONNECTED`,
the same line for a client that closed, a client that gave up and a host that dropped it.

What it answers, and what closed the 31/07 diagnosis: the distribution is BIMODAL, so either the
session lasts hours or it dies in 3 to 60 s. That alone separates "bad network" from "something
drops it", which was the question.

It SHRANK on 08/08/2026 when Tailscale left. It used to cross-reference each session with tailscaled
events and path probes to answer "was this direct or did it fall into DERP?". With WireGuard there
is no relay, so the question lost its object and those sections were removed instead of adapted.

## Setup, once

From the browser of any WireGuard peer: `https://192.168.1.10:47990`, create the admin user and
pair Moonlight with the PIN. The paired clients live in `~/.config/sunshine`, which is state, not
config.

## The bitrate ceiling, and a correction that inverts the reasoning

The default is 0, meaning "obey whatever Moonlight asks", and the client asked for up to 79 Mbps.
Across 67 sessions over 7 days (jul/2026), the 79 Mbps ones had a median lifetime of **22 s**
against **290 s** for the 23.8 Mbps ones. The cap lives on the HOST and not on the client's
slider, because that way it is declarative and holds for ANY client that pairs.

10000 became 20000 on 31/07, and two measurements changed the arithmetic:

1. The encoder in use is **AV1** (`av1_vaapi`, confirmed live), not h264 as the comment used to
   claim. AV1 delivers ~40 to 50% more per bit, so 10 Mbps already amounted to ~18 to 20 Mbps of
   h264. The ceiling was looser than it looked, but by a mistaken premise.
2. The "79 Mbps" was NOT what the client asked that week. Cross-referencing bitrate against
   encoder in the journal, the 7 days ran at 19.4 Mbps, and the SHORT sessions on 31/07 (15 to
   68 s) were ALSO at 19.4. So a short drop happens at a moderate bitrate and the cap is not what
   prevents it. The confounder is the hour: they cluster in the 08:00 window, the same one in
   which the FAI network dropped the VPN 52 times that week.

So 20000 is not an experiment, it is going back to the de facto bitrate, now explicit. The ceiling
still exists to stop a client asking for 79. It serves Cities Skylines II, where a camera pan
changes EVERY pixel (the worst case for interframe compression, despite the game looking calm);
Hearthstone, with a fixed camera, fit comfortably in 10. The 10 Mbps sample was ONE session that
did not even complete, so the previous ceiling never had a stability record.

**Correction (03/08/2026), and it is the useful part**: item 1 is WRONG for the FAI client. The
encoder is NOT the host's choice, it is NEGOTIATED, and Moonlight picks. Measured in a real
session from that machine:

```text
Creating encoder [h264_vaapi] / Color depth: 8-bit / Rec. 601
```

while the host announces `hevc_vaapi` AND `av1_vaapi`, both 10-bit, at startup. That client asks
for H.264 8-bit, the LEAST efficient codec available, so the AV1 arithmetic does not apply to it.

**The practical consequence: turning HEVC/AV1 on IN THE CLIENT'S Moonlight is worth more than any
tweak in this file**, and it is where to look first when the stream suffers. There is no host
setting that forces it; `hevc_mode`/`av1_mode` only ANNOUNCE support, which is already announced.

**FEC at more than the default 20%** because the path to FAI loses packets: measured at 1.67% loss
with RTT jumping from 20 to 312 ms in a burst of 300 packets of 1 KB. FEC recovers loss without
retransmitting, which in real time would arrive late. It costs bandwidth, which is why it travels
with the ceiling. Caveat: the measurement is ICMP, which switches and firewalls deprioritize, so it
indicates a bad path rather than proving what the video flow suffers.

**`ping_timeout` above the 10 s default** tolerates a transient hole. It only helps when the HOST
is the one giving up, and the logs cannot tell that from the client giving up. It is not free: a
dead client's session holds hypridle paused for longer.

## The apps are declared, and one factory app dropped every stream

Until 03/08/2026 this was NOT declared, so Sunshine created its own `apps.json` with the FACTORY
apps. One of them killed the stream in 2.5 s:

```text
"Low Res Desktop" with prep-cmd: xrandr --output HDMI-1 --mode 1920x1080
```

Two mistakes in one factory command: `xrandr` is X11 (here it is pure Wayland, with no Xwayland in
the capture path) and `HDMI-1` does not exist, since the real outputs are DP-2 and HDMI-A-3. A
prep-cmd that FAILS makes Sunshine abort the session, so clicking that app was a guaranteed drop.
Worse, the global guard's undo does not run on that abort, leaving hypridle stopped.

**"Low Res Desktop" was NOT reimplemented** with `hyprctl output`, on purpose: changing the video
mode WITH the wlr capture active is the same class of risk as DPMS under capture, which caused a
GPU engine reset. A lower resolution is asked for on the CLIENT, where Moonlight picks the mode and
Sunshine scales, without touching the host's scanout.

**The trade-off**: declaring `applications` makes the module point `file_apps` at the store, so the
web UI's Applications tab becomes READ ONLY. That is the price of being declarative and the right
side of rule 14. The old `~/.config/sunshine/apps.json` is now IGNORED; do not delete it by reflex
on discovering it has no effect, it is leftover from the non-declarative period.

Steam runs `detached`, so Sunshine does not wait for it (the session would die with Steam), and the
undo closes Big Picture on disconnect. `setsid` goes by absolute path (rule 7), but `steam` stays a
NAME on purpose, because what resolves it is the `programs.steam` FHS wrapper on the session PATH,
and a store path here would bypass that wrapper.

## The HTTPS handler hang, which is invisible by definition

On 29/07 Sunshine ended up with 47984 (HTTPS) accepting TCP and NEVER completing the TLS
handshake, with 22 connections stacked in CLOSE-WAIT, while 47989 (HTTP) answered 200 normally.
Moonlight uses HTTPS on an already paired host, so it showed "offline".

The worst part: the service stayed `active`, with `ExecMainStatus=0` and NOT ONE line of log. There
was no way to notice; only a `systemctl restart` fixed it. It is the same shape as the nxBender
hang in [`vpn.md`](vpn.md).

Hence the active probe: the only way to detect it is to ATTEMPT the handshake. Three attempts in
~10 s before restarting, so a hang is not confused with the service starting up. It restarts even
with an active stream, because a host with a hung HTTPS is already useless.

The timer runs every 2 min, which would make systemd log "Starting…/Finished…" 440 lines/day
(measured), so `LogLevelMax = warning` cuts the info out. **It needs `SyslogLevel = warning` beside
it**, which was missing until 19/08/2026: systemd logs a script's stdout AND stderr at INFO, so the
filter alone also swallowed everything the script did not prefix by hand. That is why the 127 above
logged no reason at all, seven times in a row. A `<3>` or `<4>` prefix carries its own level and was
always visible, which is the asymmetry that hid the crash while showing the guard's deliberate
warning.

The idle guard also has a **2 min grace** between the `do` that stops hypridle and the bind of the
video ports. In "Steam Big Picture" that window lasts the whole Steam launch, and turning hypridle
back on inside it is the 03/08 remote lockout all over again.

## The ghost session, which the handshake probe cannot see

19/08/2026, the second occurrence. A session ran from 08:15 to 08:24 and the client left with no
clean teardown. Sunshine never closed the session: `/serverinfo` kept answering
`state=SUNSHINE_SERVER_BUSY` with `currentgame=958645192` while there were **zero** UDP sockets on
47998-48000 and **no** established TCP on 47984 or 48010. Moonlight reads that state and will not
open a new session, so from the client the host is simply broken.

**The 29/07 probe cannot detect this, by construction.** The TLS handshake on 47984 completes
perfectly the whole time, because the HTTPS handler is healthy; what is stuck is the SESSION behind
it. Two different failures, the same remedy (`restart`), and detectors that share nothing. Measured
on 19/08: `sunshine-health` ran every 2 min through the entire ghost and exited 0 every time, which
is correct behaviour for what it was asked to check and useless for what was actually wrong.

The reaper's condition is `SUNSHINE_SERVER_BUSY` plus no socket, HELD for over 5 min (three probes
at 2 min) before restarting. **The hold is not caution for its own sake**: between the app launching
and the client binding video there is a window that lasts the whole Steam Big Picture launch, the
same window the idle guard needs its 2 min grace for, and restarting inside it kills a session that
was being born. Reaping a ghost 6 min late costs nothing, since nobody can connect either way.

**A restart does not lose pairing.** The paired clients live in `~/.config/sunshine`, which is state
and survives (verified on 19/08: `fai pc` was still there afterwards). That is what makes restart an
acceptable remedy instead of a last resort.

It is a mop and not a fix. The bug is upstream, in Sunshine not closing a session whose client
vanished, and `ping_timeout` does not cover it: that drops the STREAM, never the bookkeeping.

## The firewall rule can land first, and the `-s` is not redundant

The other half lives ON THE ROUTER (the `Moonlight-*` redirects), which Nix does not reach. This
rule on its own exposes nothing: without the DNAT over there, no packet from the internet reaches
these ports. That is why it can land FIRST, and that is the right order, since the reverse would
leave the router forwarding to a host that refuses.

The `-s` is the second lock, and the one that survives somebody touching LuCI without reading this
page.

**47990 is deliberately out of every list.** It is the ADMIN PANEL, the screen that creates users
and pairs clients. Whoever adds it publishes that on the internet.
