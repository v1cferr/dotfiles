# Ideas

Things considered, references, and what has not become a decision yet. What already did is
in [history/](history/); what is still to do is in [open-items.md](open-items.md).

> Quickshell: DECIDED, I migrated everything to Quickshell (see the TODO). Customizable in
> QML with hot-reload; Hyprland became hot-reload too (hyprland.lua through
> mkOutOfStoreSymlink).
> For inspiration: <https://github.com/Misterio77/Foundry>
> Nix wallpapers: <https://github.com/NixOS/nixos-artwork/tree/master/wallpapers>
> Centralized themes: `home/desktop/palette.nix` (`my.theme`). nix-colors was discarded
> (archived + base16 caps it at 16 colors).

## Blue light filter and eye strain

**If hyprsunset gains a gradual transition** (the *Graduated transition* issue, opened on
08/08/2026), the 13 profiles in `home/desktop/hyprsunset.nix` collapse into 3 (day, night
and late night) and the tool interpolates. Today it jumps abruptly, and the small steps are
what disguises the jump.

**The priority order against eye strain** is the opposite of the intuition: reducing
BRIGHTNESS comes before color temperature, and night mode does not replace adequate
brightness. That is what motivated `system/hardware/ddc.nix`: gamma darkens the signal, not
the light being emitted. The DDC/CI brightness curve was BUILT and REVERTED, since it
worked, but only on the main monitor, and the HDMI TV has no automatic path. See the august
history. What is still open:

- **Progressive gamma from 18:00 on**, the next step if the color curve is not enough, and
  it is the one that would finally apply the priority above. On 13/08/2026 the post-18:00
  curve came down ~200 to 400K per step (the 2nd descent) and the BRIGHTNESS axis was left
  out on purpose: automatic dimming through gamma existed and was reverted on 08/08 along
  with the DDC.
  The Kelvin curve got close to the useful floor, since it already crosses the ~3200K
  where the color ruins media, so going further down in K makes the color worse without a
  proportional relief. If the discomfort comes back, the adjustment is gamma, not more
  orange.
- **Bias lighting**, a light behind the monitor. It is the recommendation that shows up
  most in the literature and the only one that is not software: it reduces the contrast
  between the screen and a dark wall.
- **PWM**: a monitor that dims through PWM flickers at low brightness and makes fatigue
  worse. Check whether the panels are flicker-free before lowering the backlight too far.

## NetBird: a CGNAT contingency, not a replacement

<https://github.com/netbirdio/netbird>, WireGuard with a control plane: peer discovery,
automatic NAT traversal, per-device ACL and SSO. Evaluated on 10/08/2026, the same day the
Moonlight direct access landed.

**DECISION: stay with the router's WireGuard alone. Do not switch, and do not run both.**

The framing that matters is not "switch or not", it is that the current design rests on a
single premise: **Alcans gives a real public IP**. Port forwarding, WireGuard on the router
and DDNS all three depend on it. If that changes, they fall TOGETHER, in the same minute.
NetBird is the plan for that day, and this analysis exists so it does not have to be redone
under pressure.

### Why not now

- **It requires an agent on every machine**, which is exactly what was refused: the FAI
  notebook already runs nxBender + openconnect, and the NetBird agent manages routes
  dynamically, the same class of conflict, harder to debug than a static `wg-quick`.
- **It reintroduces the relay.** It falls back to Relay/TURN when P2P fails, which is
  Tailscale's DERP under another name, the reason Tailscale went out on 08/08. And on the
  FAI network, which drops SYN-ACK, a P2P failure is the LIKELY scenario: it would relay
  precisely there.
- **The router cannot be the server.** The management side asks for "1 CPU and 2 GB"; the
  WR3000 has 128 MB of RAM and ~1.3 MB of free flash. The agent runs on OpenWrt, the
  control plane does not.
- **Self-hosting creates a circular dependency:** management + signal + relay would go to
  the PC, which is the machine you are trying to reach. Today that loop does not exist,
  since the router is a separate device that is always on. Using their cloud solves the
  circle by adding the third party back.

### What it would actually solve (and why it stays written down)

1. **CGNAT**, the trigger. With a relay, it survives what would kill everything today.
2. **Adding a peer without editing UCI by hand.** Today that is SSH into the router;
   `router-sync` is pull-only. Real friction.
3. **Per-device ACL.** Today the Sunshine rule trusts the ENTIRE `10.10.10.0/24` range, so
   the phone, the notebook and the workstation have exactly the same access. This is a real
   limitation of the current design, independent of CGNAT.

### Trigger to reopen

The home public IP no longer answering from outside. A test that does not lie (an
independent external vantage point, never from inside the LAN, because the ISP does
hairpin):

```sh
curl -s "https://check-host.net/check-tcp?host=<ip>%3A2222&max_nodes=3" \
  -H "Accept: application/json"
```

## "Everything on the router": what it already is, and what it cannot be

My idea (10/08/2026): concentrate services on the router so that nothing stops when the PC
goes down (power outages and the like).

**GOOD NEWS: the ACCESS layer already is exactly that.** These run on the router and do not
depend on the PC: WireGuard (`wg0`, the router is the server), DHCP, DNS with adblock-fast
and https-dns-proxy, firewall/SQM, and Wake-on-LAN (`/usr/bin/wake-desktop`). The PC can be
off and the VPN still comes up and the home network still works.

**What CANNOT migrate:** Jellyfin, Sunshine, Caddy, qBittorrent and Ollama. It is not a
matter of willingness, it is 128 MB of RAM and 1.3 MB of free flash. Screen streaming and
media transcoding do not fit by any order of magnitude.

**And the bottleneck in the "power went out" scenario is NOT the router, it is the PC
coming back on its own.** That is BIOS (*Restore on AC Power Loss* = Power On), not Nix,
and it is not declarable in this repo. WoL does NOT replace it: after a real power cut the
NIC loses the state armed by `ethtool`, and it only comes back if the BIOS itself keeps
wake enabled. The right order to attack it: (1) the BIOS powers back on by itself, (2) WoL
as the rescue for a normal shutdown, (3) a UPS on the router and modem if the intent is to
keep the internet up DURING the outage, but that does not turn the PC on, because the PC is
not on the UPS.

`router/uci/etherwake.conf` is DEAD CONFIG: `name='example'`,
`mac='11:22:33:44:55:66'`, the factory placeholder of the LuCI app, never filled in. What
works is `/usr/bin/wake-desktop`, with the MAC baked in. Do not trust the LuCI screen.
