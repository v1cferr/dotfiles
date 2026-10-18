# The bar, and its popovers

`modules/home/desktop/quickshell/bar/`. The desktop's bar, the only one; Waybar left in the migration to
Quickshell. It is loaded by `shell.qml` (`Bar {}`), and the popovers live in files next to it.

It shows: the workspaces per monitor plus the title, the NixOS logo (the way into notifications and
the session, [nixos-center.md](nixos-center.md)), the clock, cpu/temp, audio (Pipewire), Spotify
(Mpris), the network, the VPN and Tor, the weather, the tray, and on the standing monitor the
operational alerts.

## The Powerline (17/10/2026)

The bar is ONE continuous 40 px glass strip across each monitor: no margin to the screen's edges, no
transparent gap between sections, a hairline at its foot. Earlier the same day it was three floating
clusters; the brief that replaced them asked for one connected surface, with the logo at its center.

| Part | What it is |
| --- | --- |
| The surface | `colSurfaceBar` edge to edge, a 1 px `colEdge` line under it |
| Dividers | `Chevron.qml`: one 1 px diagonal across the bar's height, leaning `\` on the left half and `/` on the right, mirrored on the center |
| The center | `LogoSlot.qml`: a 64 px compartment, a shade lighter, its edges the two mirrored diagonals, the official logo at 22 px and the one blue line on the bar under it |
| Controls | `widgets/Pill.qml`, flat 28 px controls (hover fill, press fill, an accent fill while pinned) |

**The logo sits on the screen's EXACT center, and nothing beside it can move it.** Its compartment's
x is `floor(width / 2) - 32`, computed from the bar's width alone, never from its neighbors: on the
ASUS the logo's center is x 1280, on the LG x 540. Each side is capped at what is left of it before
the center group (`leftRoom`, `rightRoom`), so it can never reach it.

## The distribution (18/10/2026)

The main monitor reads `Workspaces, title, media | time, logo, date | weather, CPU, network, VPN,
sound, idle and away, tray`, and the standing monitor `Workspaces, title | logo | operational chips`.
Since 18/10/2026 (v2.3) the temperature is not on the bar: it is in the NixOS Center's hardware row,
which opens the temperatures panel ([nixos-center.md](nixos-center.md#hardware)). The disk shows only
when it needs a look (below).

**The center group is placed, never centered as a group.** The time (`HH:mm`) and the date (`dd/MM`)
sit in two MIRRORED slots of ONE width, measured once from a template (`TextMetrics` over `00:00`, the
same font, size and weight for both; the face is mono, so every minute and every date is that wide),
and their x comes from the compartment's slanted edges: the time ends one `sp1` before the left
slant, the date starts one `sp1` after the right one, each with a divider on its outer side. So the logo stays on the screen's center whatever the strings
hold, and a new minute or day moves nothing. The group's outer edges (`centerLeft`, `centerRight`)
are pure functions of the bar's width; each side's room is what lies between them and an 8 px edge
margin, less an 8 px gap. On the compact bar the center group is the compartment alone.

**The left side splits its room by rules that read the room alone, never a text.** With a player up
the media takes up to 220 px, the title keeps at least 240; with less room the media shrinks toward
120, then becomes its icon alone, and only then does the title give way, hiding under 120 px instead
of becoming a stub. Without a player the media is gone, divider included, and the title gets its
room. Since no level reads a song's or a title's text, a track change can never flip one. The
title's own width comes from `TextMetrics` and is rounded UP to 64 px steps (its text left-aligned),
so most focus changes do not move the media beside it. The hover hint keeps the full title.

**The right side folds the same way it did, the tray protected.** `rightRow.measure(level)` no longer
counts the time, the date or the media; it counts the weather, the CPU (and the disk when shown), network and VPN,
volume, hypridle and away, and the tray. Level 1 drops the network's numbers and the VPN's name (the
icons and their panels stay), level 2 the weather. The tray is never folded.

**The tray is pinned to the right edge** (`TrayStrip.qml`, its own file since this change): anchored
8 px from the edge, growing left, and the rest of the right side anchored to ITS left edge with a
width from the item count alone (`count` x 28 px plus the spacing), never from the delegates. So a
throughput, a temperature or a VPN name changing width moves only what is left of it. No overflow
menu was built: on the ASUS the right side has room for about a dozen more icons before even level 1,
and an overflow nobody needs is code to keep.

**Popovers.** The calendar, from the time or the date, hangs from the logo, so it opens centered on
the screen and never jumps between the two; the media panel hangs from the media pill wherever it now
is (`popLeft`, clamped to the screen), with no change to `Mpris.qml`. Every other panel kept its anchor.

**The disk, only when it needs a look.** A chip next to the CPU appears when the root filesystem is
past 90% or under 20 GB free (warning), past 95% or under 5 GB free (critical), read from the `df`
the bar already runs every 30 s; it opens the CPU and memory panel, which holds the disk detail.

**The main monitor gone.** The standing monitor's bar shows the tray at its right edge, the alerts
moving left of it, only while no screen is wide enough for the full bar (`wideUp`), so the tray never
disappears with the monitor that held it, and is never shown twice.

**Measured on 18/10/2026**, from captures of the live bars, before and after:

| Check | Before | After |
| --- | --- | --- |
| The blue line under the logo, ASUS | 1257 to 1302, center 1280.0 | the same |
| The same, LG | 517 to 562, center 540.0 | the same |
| The last tray icon's right edge | 17 px from the ASUS edge (the clock was last) | 15 px: the 8 px margin plus 6 px inside the 28 px control |
| Tray icons across six captures 2 s apart | | each on the same x (2402, 2435, 2468, 2499, 2530) |
| The right group's left edge, same captures | | x 1892 every time |
| `qs log` after the swap | | no binding loop, no error |
| v2.3, the time and the date (ink of `16:05` and `18/10`) | | 1193 to 1226 and 1333 to 1366: 53 px from the center inside, 87 outside, on both sides |

Not verified by hand: a long song or title, no player at all, many tray icons, a monitor unplugged,
and opening each popover from its new place; the rules above are what bound those, and they are the
owner's to try at the desk.

**The official logo** is `nix-snowflake`, the two-blue snowflake from
[nixos-artwork](https://github.com/NixOS/nixos-artwork) that `nixos-icons` installs into hicolor on
every NixOS system, resolved with `Quickshell.iconPath("nix-snowflake", true)` and drawn as a vector
at its own aspect; the Nerd Font glyph (`U+F313`) is only the fallback. A copy of the SVG in the
repo was rejected: the system already ships the source of truth, from the same Nix build.

**Measured on 17/10/2026:** the bar layer at x 0 with the screen's full width and 40 px on both
monitors; the ASUS reserving 40 px and the LG 672; the calendar and the NixOS Center opening
centered on 1280; screenshots of both monitors show one continuous strip.

### Numbers that hold still

The temperature, the CPU, the two network rates and the volume are padded to a fixed number of
columns (`tab()` in `Bar.qml`); the font is mono, so the pill keeps its width. Before, `431K`
becoming `1.3M` or `9%` becoming `41%` moved every control to their left every 2 s, since the right
cluster is anchored to the edge. Measured on 17/10/2026: the cluster's left edge sat on the same
pixel across six captures 2 s apart while the rates changed.

## Contextual expansion: one panel at a time (17/10/2026)

Every panel the bar opens on hover (weather, calendar, temperature, usage, network, VPN statistics)
goes through ONE coordinator in `Bar.qml` and one window type, `bar/BarPanel.qml`. It replaced four
separate hover machines that each kept their own "pill hovered", "popover hovered" and close timer.

| Gesture | What it does |
| --- | --- |
| Hover | after 200 ms of rest (`Theme.hoverIntent`) the panel opens; a pointer only crossing the bar opens nothing |
| Hover a neighbor | its panel takes over at once, with no new wait |
| Leave | 300 ms of slack to cross the gap into the panel, then it closes |
| Click | PINS it: it stays without the pointer, and its pill stays lit |
| Click again, click outside, Escape | closes the pinned panel |
| Click another pill | switches the pin to that panel |
| Scroll | unchanged (volume, media) |

The logo's panel, the NixOS Center, is in the same coordinator under the key `center`, and opens on a
CLICK only ([nixos-center.md](nixos-center.md)). EVERY bar is in a pinned panel's focus grab, so a
click on the other monitor's bar reaches it: the same panel moves there, another one switches.

**One panel at a time.** A pin closes the VPN actions menu, the power menu and any hint; opening the
power menu, the VPN menu or the media panel closes a pin; a hovered panel hands over to a hint the
moment the pointer reaches a pill with no panel. Two panels can never draw over each other.

**Click outside, and Escape, without stealing the keyboard.** A pinned panel holds a
`HyprlandFocusGrab` whose whitelist includes the bar window it hangs from, which is why a click on
another pill SWITCHES panels instead of only closing (outside the whitelist the grab clears and the
panel closes). The panel asks for the keyboard (`OnDemand`) ONLY while pinned, so a hovered panel
never takes it from the window under it, and the grab is what delivers Escape. This is the same
layer-surface pattern as the tray menu, for the same Hyprland #6682 reason
([quickshell.md](quickshell.md#traymenu-why-a-layer-surface-and-not-a-popupwindow)).

**Placed from the screen's edge.** Every bar panel uses `exclusionMode: Ignore` with its top at
`Theme.bandTop` (the bar's 4 px gap, its 30 px, and 4 px more), so it lands the same 4 px under the
bar on both monitors; relying on the reserved zone would drop it under the whole glance band on the
standing monitor, whose bar reserves the band's strip ([dash.md](dash.md)). The media panel follows
the rule too, hung under its pill through `qs ipc call mpris toggleAt <x>`.

**Two clicks changed meaning**, and both old actions moved to the right click: the weather's
forecast site (it was the left click) and the network's `nm-connection-editor` (same).

**Tested on 17/10/2026** with a virtual pointer and keyboard (`wlrctl` and `wtype` from nixpkgs, not
installed), reading the mapped `qs-panel` layers after each step: nothing at 80 ms of hover and the
panel at 500 ms; the neighbor's panel at 80 ms; closed 500 ms after leaving; pinned and still there
600 ms after the pointer left; closed by Escape; switched by a click on another pill; closed by a
second click; closed by a click on the glance band; the volume hint shown 100 ms after leaving the
weather's panel; the power menu closing a pin.

## Hiding the bar (the IPC handler)

It exists because of Flameshot's overlay: on Hyprland a normal WINDOW never covers a `top` layer,
and the bar lives in one, so the overlay shows a FROZEN frame that already contains the bar and the
LIVE bar draws on top, giving the "duplicated bar" effect. There is no window rule that solves it
(an open feature request, hyprwm/Hyprland#4847), so the only path is hiding. See
[`flameshot.md`](../apps/flameshot.md).

`visible: false` unmaps the layer surface, so the 30 px strip stops capturing clicks, which matters
for selecting a region at the top of the screen.

**Do NOT name the handler "show"**: it collides with the `qs ipc show` subcommand and the CLI never
calls the function. The same trap is documented in `shell.qml`, in the vpn `IpcHandler`.

## The workspace rail (18/10/2026)

`WorkspaceStrip.qml`, the ADAPTIVE WORKSPACE RAIL: each monitor's workspaces as two-digit numbers
(`01` to `04` on the ASUS, `05` to `08` on the LG), every button one width measured from `00`, under
the one sliding active pill that was already there.

| State | Looks |
| --- | --- |
| active | dark bold number on the blue sliding pill |
| occupied | bold `text` number, a 2 px rule under it |
| empty | `dim` number at 70% |
| a window opened there | a steady 5 px yellow dot (`colWarn`) |
| a window there asked for attention | a steady 7 px orange dot with a ring (`colAlert`) |

The two marks used to be one, and pulsed forever. They are now apart, since a window that merely
opened is news and an urgency is a request (`wsActivity` from the window count, `wsUrgent` from
Hyprland's `urgent` event), and steady: visiting the workspace clears both. A hover shows a tip with
the window count and the windows' classes, from Hyprland's own toplevels, read only on hover. The
click, the keybinds, the orphans of a gone secondary and the slide are unchanged.

## The standing monitor's bar: status first

`compact` reads the panel's own WIDTH, below 1600 px, and not "is this the secondary", so rotating
the monitor back restores the full bar with no config change (rule 3). On the 1080 px LG the bar
keeps the logo at x 540 and holds:

- **Left:** that monitor's workspaces, and the window title when it fits cleanly.
- **Right:** the operational alerts (`OpsIndicator.qml`) and nothing else. No clock: the band right
  under it shows the time at 72 px. Nothing the band's cards already show is repeated. The one
  exception is the tray, and only with no wide screen up ([the distribution](#the-distribution-18102026)).

**On the standing monitor the bar reserves the band's strip too.** Its `exclusiveZone` there is the
whole top share (672 px at 35%), and the band draws inside that strip ignoring other zones. Two
layers that each reserve their own zone are stacked in the order they MAP, and on 17/10/2026 a
re-created band mapped first and pushed the bar under itself; with one owner the order cannot matter
and nothing is reserved twice.

### Operational chips

One chip per SOURCE that needs a look, `CI · 2` and `SVC · 1`, from the feeds the band already reads:
no new polling, no API call of its own. The verdict is computed ONCE, in `dash/Ops.qml`, which both
the chips (`OpsIndicator.qml`) and their panel (`OpsPanel.qml`) read, so the two can never disagree.
Each chip is a state icon, a short name and a count, in a width measured from `SVC · 00`, on the
glass tinted by its state (`Pill.fill`).

| State | Chip | Means |
| --- | --- | --- |
| healthy | nothing but a dim check | every source answered and nothing is wrong |
| failing | `󰅚 CI · 2` red | two current failures across GitHub and the FAI GitLab |
| running | `󰑮 CI · 1` neutral | nothing failing, one run in progress |
| degraded | `󰀪 SVC · 1` orange | a service with fewer units running than expected |
| failing | `󰅚 SVC · 1` red | a service down |
| stale | `󰥔 CI · 2` dim | a forge answering only with old data: the count is its LAST KNOWN one |
| unknown | `󰋗 CI · ?` dim | a forge never read, or the services meta silent for two minutes |
| folded | `OPS · 3` | both sources, in the worse state's colors, when the room is too small for two |

**"Current" is the latest run of each workflow (or each GitLab ref).** glance-feed keeps only the
newest run per workflow in its 7-day window, so a failure a later run fixed is already gone from the
document, and only a failure that still stands is counted. A forge that never answered is unknown,
not healthy; one that answers with its last good picture is stale, and its failures are reported as
the last known state, never as the present. The FAI GitLab only counts once it has answered at least
once, the same rule that keeps its page out of the band's rotation.

**A hover opens the status panel** (`OpsPanel.qml`, keys `ops-ci`, `ops-svc`, `ops`), through the
same coordinator as every bar panel: the verdict, a summary (`2 failing pipelines`), how fresh it is,
then each forge with its failing runs (repo, workflow or ref, age) or the services not up
(`running/expected`), then the actions. **Freshness is the feed's own time:** `checked_at` of the CI
document, re-read from the cache (no network) each time the panel opens, and the services' `fetched`.
A stale source says `last known state`; a missing one says `unavailable`.

**A click shows the detail on the band:** CI turns the band's pages to the forge with a failure,
SVC turns the services strip to its first page (trouble sorts first), and both rotations hold for
30 s. The panel's `Show on dashboard` does the same; `Open details` appears only when a failing run
has a URL, and opens it. The bar reaches the band through the Bar's `dashRequested` signal; the two
already share that scope, so no navigation controller was needed.

Tested on 18/10/2026 with the live feeds: the LG chip read `CI · 2` in red; hovering it opened the
panel with `2 failing pipelines`, `CI updated now`, GitHub healthy and the FAI GitLab's two failing
pipelines with their ages, and both actions.

## The clock

The time AND the date are ALWAYS visible, on each side of the logo on the main monitor (18/10/2026;
before, at the right end after the weather): `HH:mm` and `dd/MM`, the same font, size and weight in
`text`, in mirrored slots (v2.3; the first version had `Dom, 18 out` in a lighter weight). The SECONDS left the bar but not
the clock: `timeStr` keeps `HH:mm:ss` for the band's big clock, and the bar reads `barTimeStr`, which
only changes once a minute. Never on the standing monitor (the band shows it). Both open the
calendar, hung from the logo.

Both are numeric, so no locale can change them; where a weekday or a month is spelled (the calendar,
the band) it comes from local `dowAbbr` and `monAbbr`, NOT from Qt's `"ddd"`, which follows the
PROCESS' locale. There is no year; whoever needs it has the calendar on hover.

## The system snapshot: one read per tick

The bar used to read the machine through FIVE forks on three cadences: `/proc/stat` every 2 s,
`/proc/meminfo` every 5 s, `sensors -j` and the GPU hwmon every 3 s, `/proc/net/dev` every 2 s.
Today it is ONE `head -n 200 -v` over a fixed list of /proc and sysfs paths.

The trick is `head -v` itself: with several files it prefixes each one with `==> path <==`, so the
output is SELF-LABELING and the QML splits it by section, with no marker of our own to keep in sync
between the shell and the parser.

MEASURED on 18/08/2026: 9 ms and 16 KB per snapshot, against 11 ms for the `sensors -j` call ALONE
that it removes. Fewer forks and five times the data.

Every rate on the panels (the CPU percentage, the disk's I/O, the throughput, the GPU's watts) is a
DELTA between two consecutive snapshots divided by `sysInterval`, never a number the kernel hands
over ready. That is why the interval is a property and not a literal: change it in one place and
every rate stays correct.

### Reading hwmon directly, and not `sensors -j`

Two reasons, and the second one is a bug that was live:

1. **Each sensor's own limit comes with it.** `tempN_max` is where the part starts throttling and
   `tempN_crit` is where it gives up, and without them a panel can only draw `temp / 100`.
2. **`sensors -j` LOSES data on this machine.** The `xe` chip publishes two entries named `card`
   (one with `power1_cap`, another with `energy1_input`), and a JSON object cannot hold a repeated
   key, so whichever parses it keeps only the last: the GPU's power cap disappears on parse.

The chip FAMILIES are matched by prefix (`coretemp`/`k10temp` are the CPU, `xe`/`i915`/`amdgpu` the
GPU, `nvme`, `acpitz`/`nct`/`it87` the board), so another machine does not need a new branch here.

That also fixed a reading that never appeared: the old code looked for a chip named `nct*` to get
the board temperature, and this machine HAS NO `nct`. It has `acpitz`. The row was empty for months
without ever failing, which is the silent-drift failure rule 16 describes.

### The GPU reading

Intel Arc B580 on the `xe` driver, and the usage percentage does NOT exist: the driver publishes no
`gpu_busy_percent`, and `intel_gpu_top` only speaks i915 (verified on 18/08/2026: "No device filter
specified and no discrete/integrated i915 devices found"). The old bar drew that absence as a
literal `0%`, which is the same class of lie as the pretty-and-false latency the VPN probe exists
to avoid.

What the card DOES publish is measured and real, so that is what the panel shows: the render clock
against its ceiling (`tile0/gt0/freq0/act_freq` against `max_freq`, 400 to 2850 MHz here), the whole
BOARD's power (the `energy1_input` counter in microjoules, turned into watts by the same delta as
every other rate, against the 210 W `power1_cap`) and the fan's RPM.

`energy1` is the board and `energy2` is the chip alone; the board is what the power supply actually
delivers, so that is the one on screen.

## The three system panels

The temperature, usage and network pills opened the SAME popover: a title, a list of label/value,
and a bar drawn at `value / 100`. It answered "how much" and stopped there, while the VPN panel
right next to it answered "is this fine, and since when". The three now speak that same language:

| Panel | Verdict | Graph | Provenance |
| --- | --- | --- | --- |
| `UsagePopover.qml` | idle to stalling | the CPU over 2 min, plus one bar per thread | the CPU model, cores/threads, uptime |
| `TempsPopover.qml` | cool to critical | the hottest sensor over 2 min | how many sensors, and from which chips |
| `NetPopover.qml` | offline to steady | throughput mirrored over 2 min | the interface, its type, who manages it |

The window is 60 samples at one every 2 s, so two minutes, and it accumulates whether the panel is
open or not, because the snapshot that feeds it runs anyway. Opening the panel costs nothing extra,
with one exception below.

### What each one answers that a number could not

**Usage.** One bar per THREAD, because an average of 20% is a different machine when it is one core
pinned at 100 and when it is twelve at a fifth, and only the shape tells them apart. The load is
shown PER THREAD as well: a raw "8" means nothing without knowing there are 12 of them. Memory is
counted against `MemAvailable` with the cache on its own row, since the cache is memory you HAVE and
reading `MemFree` is what starts every "my RAM is full" panic.

The kernel's PSI stall percentages only show up when something actually stalled. A row pinned at
0.0 trains the eye to skip it, and this is precisely the row that has to be noticed the day it
moves. Same rule as the VPN panel's errors row.

**The heaviest processes are the exception to "costs nothing".** `ps -e` walks all of /proc, so that
poll only runs while the panel is OPEN, the same gate the VPN probe uses. It answers the one
question an aggregate never can: who is eating the machine. `ps` itself always reads as 100%, since
its CPU time covers its whole tiny life, so it is filtered out in the parser, where it does not
fight with the shell quoting.

**Temperatures.** Every sensor is drawn against ITS OWN ceiling. The old `temp / 100` compared the
incomparable: a CPU package at 47 of a 100 ceiling and a GPU package at 47 of a 60 one drew exactly
the same bar. The row's context now says "throttles at 82, crit at 100", which is the number that
decides whether 78 degrees is fine.

The chip's remaining sensors are condensed on ONE line, grouped by family by stripping the trailing
number: 6 cores and 12 VRAM channels stay two strings instead of 18 rows. The NVMe's `Sensor 2` is
one of them on purpose: the drive's thermal thresholds apply to `Composite`, so that is the
headline, and the hotter secondary sensor is detail and not an alarm.

**The GPU fan says "stopped", not 0.** This card idles at zero RPM and only spins up under load, and
a bare `0 rpm` reads as a dead fan.

**Network.** The throughput graph is MIRRORED, download growing down from the top and upload up from
the bottom, sharing ONE ceiling. Two scales would be prettier and would lie about which direction is
bigger. The floor is 128 KB/s so an idle link is not a dramatic sawtooth, the same reasoning as the
VPN graph's 60 ms floor.

**The main interface comes from the DEFAULT ROUTE**, not from the literal `enp7s0` that used to be
written into the parser. That is what "main" means, and it works on a machine that never saw this
motherboard.

**The link probe aims OUTSIDE the ISP** (an anycast anchor, 1 packet/s, the same
`widgets/PingProbe.qml` the VPN uses). Whether the cable is plugged in is already answered by the
carrier flag and the gateway; what was missing is everything past the router. The verdict follows
the VPN's order of the damage: no carrier, then no gateway, then loss, then jitter, then the mean.

## The VPN: three surfaces, one source

`vpnList` holds the RAW list `[{id,name,connected}]` because the popover needs one row per VPN;
`vpnConnected`/`vpnName` remain the aggregate the pill shows. A single read feeds both.

That matters: rofi used to reassemble the labels on its own with `systemctl is-active`, which LIES
during nxBender's crash loop, saying "active" with no tunnel existing. See [`vpn.md`](../network/vpn.md).

Connecting and disconnecting uses a `Process` and not `launch()`, so we know WHEN it finished: the
state is reread right away instead of waiting for the 5 s poll, and `vpnBusy` holds the panel open
and the buttons inert during the action.

**The split is intentional: INFORMATION on hover, ACTION on click.**

- **`VpnPopover.qml` (click)**: one row per VPN with a state dot and a Connect/Disconnect toggle,
  plus "Disconnect all". It REPLACES the rofi menu (`vpn menu`), which was a LOOSE window in the
  middle of the screen with no visual relation to the bar and outside the shell's theme. It is a
  click and not a hover because you click buttons inside it, and a panel that opens on hover closes
  at the first distraction. Same choice as PowerMenu, which also has actions inside.
- **`VpnStatsPopover.qml` (hover)**: the quality verdict, a graph of the last minute, latency,
  jitter, loss, traffic and uptime, then Tor's rows. It has nothing to click, the same criterion as
  the calendar and the three system panels. It opens with NO VPN up too ("none connected" plus
  Tor), because a hover that shows nothing reads as a broken pill.

Both anchor at the SAME point of the bar, so the Bar hides the stats one while the actions menu is
open; otherwise one would draw on top of the other, since the mouse stays over the pill the whole
time.

Right click on the pill is still the shortcut for taking everything down.

### The hover hint: every item answers a hover

Asked for on 10/10/2026: everything on the bar shows something under the cursor. The pills with a
panel of their own (weather, clock, temperature, usage, VPN, network) already did; the rest (the
window title, Spotify, volume, hypridle, away, the operational alerts and each tray icon) get
`HintPopover.qml`, a small card with the state and what each button does. The click keeps doing
what it did, so a hover never fires an action.

**Since v2.3 every hint has the same three lines and the same timing.** What it is (the title, in
`text`), how it is now (`subtext`), what a click does (`dim`): `Volume / 62% · Speakers / Click to
mute`. It waits `Theme.tipDelay` (300 ms) before showing, so a sweep across the bar shows nothing;
once one is up, a neighbor takes over at once (a 120 ms grace covers the gap between two pills).
Every click that opens something cancels a pending hint too (`hideHint()`), so none appears late.
Inside a panel (the NixOS Center's icon buttons) the same card is `widgets/GlassTip.qml`, drawn in
the panel's own window; Qt's native `ToolTip`, which drew a light box off the theme, is gone.

The Bar stores a KEY (`hintKey`), not the text, and the popover binds to `hintFor(key)`. So the
hint follows the state while it is open: scrolling the volume updates its percentage live. A click
that opens something (the media panel, the NixOS Center, a tray menu) hides the hint first,
or the two would draw on top of each other. A tray icon's hint is its own SNI `tooltipTitle` and
`tooltipDescription`, with the HTML some apps put there stripped.

Every clickable item also shows the pointing hand, as the dash already did.

### Tor: a purple badge on the VPN pill, never its green

Tor rides on the VPN pill as a BADGE: the Tor glyph (`U+F371`, `linux-tor` in the Nerd Font) in
Tor's purple (`Theme.colLavender`), last in the row, shown while any Tor below runs and followed by
`Bisq` while Bisq's does. One pill and not two because both can be up at once (FAI plus Tor), and
the badge has its own color so the VPN's green keeps meaning only the VPN. Both VPN popovers,
the hover one and the click one, show Tor's STATE below the VPN rows (`TorRows.qml`):

- **System Tor**: `tor.service` active, so the SOCKS port on `127.0.0.1:9050` is up.
- **Bisq 2**: a `tor` process owned by my user whose command line runs from `Bisq2/`, the child
  Tor Bisq starts with the app and kills on exit. A Tor owned by `tor` is the system one, so the
  owner tells them apart.

The click popover adds a **Turn on / Turn off** button on the System Tor row only. It runs a
plain `systemctl start|stop tor.service`. On 10/10/2026 a polkit rule granting it silently was
rejected (a button is not worth weakening auth on a root service); on 16/10 Tor became ON DEMAND
and the rule went in after all, because `mega-dl --tor` has to stop it UNATTENDED at the end of a
download that can take hours, where a password prompt would just hang. The rule covers
`tor.service` alone, and that unit is a client-only SOCKS on loopback
([tor.nix](../../../modules/nixos/network/tor.nix)). Boot never starts it, so it stays off until
something asks. Bisq's Tor has no button: closing Bisq is what stops it.

Stack Wallet gets no row: its Tor is a library inside the app's process, with no process or
service to observe from outside, so a row would be a guess. Its own indicator is the truth.

It never turns the pill green (chosen 10/10/2026; a separate purple pill came first, then merged
into this badge so one glance shows both). The green means "this machine's traffic goes through
a tunnel", and Tor never does that here: MEASURED on 10/10/2026, a request through
`--socks5-hostname 127.0.0.1:9050` reported `IsTor: true` on `check.torproject.org`, and the same
request without the proxy reported `false`. A green pill for Tor would say the opposite of that,
which is why the popover's footer spells out what it does not cover. Why each app has its own
Tor: [`crypto.md`](../apps/crypto.md).

## The VPN quality probe

The pill only answered "is there a tunnel?"; what was missing was "and is it any good?", which is
the question of somebody with an SSH session or a call depending on it.

TWO SOURCES, on purpose: `vpn stats-json` brings the STATE (iface, IP, MTU, uptime, bytes, and
which host serves as the target) every 20 s, 3 s with the panel open, and the latency comes from a
CONTINUOUS probe. With no tunnel none of it runs, so the cost at rest is zero. That is why it did
NOT go into `status-json`, which runs every 5 s all day long just to paint the pill.

### Why continuous, and not a burst on every read

MEASURED on 14/08/2026 on the FAI tunnel, and it is what condemned the first version:

| Method | mdev | peak | loss resolution |
| --- | --- | --- | --- |
| 3 packets in 0.6 s | 0.4 ms | — | 33% (3 packets!) |
| a 20 s window | 3.3 ms | 54.7 ms | — |

The burst observed 3% of the time, so a 2 s hiccup was invisible in 97% of cases, and 1-3% of real
loss showed up as "0%". **A pretty, false number is worse than an absent number.**

THE COST is negligible and it was measured: 84 B/s, and 30 packets at 1/s gave 0% loss, so the
target does not rate-limit at that cadence. The 60-sample window gives real jitter and a loss
resolution of 1.7%.

`ping` is LINE-BUFFERED even when writing into a pipe (verified: one line per second, with no
`stdbuf`), so the stream can be read instead of waiting for it to finish.

Three flags carry weight: `-O` emits "no answer yet" at timeout, and without it a lost packet would
be SILENCE and the series would only hold the ones that came back, an eternal 0% loss; `-n` skips
DNS; `-W 1` matches the 1 s interval.

**WHAT DISCOVERS THE TARGET is the CLI** (`modules/nixos/network/vpn.nix`): sweeping routes and testing
candidates is shell work, while observing all the time is the work of whoever stays open. With no
target this probe simply does not come up and the panel says "no probe".

### The watchdog

With `-O`, ping SPEAKS every second even when the target disappears, so SILENCE is not packet loss:
it is the probe broken (a dead process, an interface recreated under it). Without the watchdog the
panel would freeze showing the last good window, looking "stable", which is exactly the lie it
exists not to tell. It marks the hole in the series AND resurrects the process.

### Two QML details that cost debugging

- **`info` ARRIVES from outside** (this VPN's object in `vpn stats-json`) instead of being fetched
  inside. An inline component does not see the `id` of the document that declares it, so a
  `root.vpnStats[...]` from in there blows up with a ReferenceError and the whole instance is never
  born. The symptom was `vpnProbeStat` becoming undefined.
- **A new tunnel, or a new target, is a NEW series.** Splicing two sessions would draw a step that
  never existed. The IP goes into the key because the interface's NAME repeats: on a reconnect
  `ppp0` becomes `ppp0` again (seen on 14/08/2026, the IP going from 192.168.50.2 to .3), and
  without it the series would cross the drop as if nothing had happened.

### The verdict's cutoffs

Anchored to the MEASURED baseline of the FAI tunnel (14/08/2026, 1 packet/s: a ~34 ms mean, 0.8 ms
mdev, 0% loss).

**The ORDER is the order of the damage**: loss first, since it kills a session; then jitter, then
the mean, because 200 ms of steady latency is workable and 40 ms of jagged latency freezes SSH and
calls.

The NUMBERS are not guesses: 2% loss is 2 packets lost in the 60-sample window, and one stray
packet a minute is far too routine to raise an alarm; a 10 ms mdev is an order of magnitude above
what a healthy tunnel measures. It says "measuring…" before 5 samples, because a verdict with 2
packets is guesswork.

The tunnel interface's rate RIGHT NOW comes from the `netRates` the bar already computes every 2 s
from `/proc/net/dev`, since `stats-json` does not repeat that calculation. An idle interface does
not show up in that list, and "it did not show up" means 0 B/s.

### The graph is the reason the panel exists

"Is the VPN steady?" is a question about TIME: a lone "34 ms" does not distinguish a smooth tunnel
from one that swung between 30 and 900 ms in the last minute.

One bar per second (60 = the probe's whole window), the most recent on the right, and **the scale
starts at ZERO**: auto-scaling from the minimum would turn 0.5 ms of variation into a dramatic
sawtooth, the opposite of an honest read. The ceiling has a 60 ms floor so the normal case does not
become a sawtooth either, and goes 15% above the peak when it passes that.

A packet with no answer is a FULL bar in faded red: the hole has to JUMP OUT, not disappear. The
test for it is broad because the series' null can arrive as `undefined`, depending on how the model
is converted.

The panel is 360 wide and not 300: in the first version the footer cut the probe's IP
("200.136.209…") and the rows were squeezed. A diagnostics panel with elided data is a
contradiction, since whoever opens it is precisely after the detail. The graph carries a legend,
because without it the drawing does not say what it covers, and "1 packet/s" is the information
that separates this panel from a guess.

## The weather

Open-Meteo, and the coordinates plus the WMO code to pt-BR table are the SSOT in `my.weather`
(`modules/home/desktop/weather.nix`), read through a generated JSON the same way the palette is.

The pill's ICON derives from the integer `weather_code`, NEVER from the label. It used to regex the
en-US prose, so translating the label to pt-BR would have turned every icon into the default cloud
in total silence. That trap, the 4-degree disagreement with the lock screen that motivated the
SSOT, and the measured failure paths are in [`weather.md`](weather.md).

## The holidays table (rechecked 08/08/2026)

The NAMES stay in pt-BR on purpose: they are the official names of Brazilian holidays, the same
class of literal as the city's name. The chrome around them is en-US.

`scope` is `"nac" | "sp" | "sc"`. `off` is the offset in days from Easter SUNDAY (the movable
dates); otherwise a fixed m/d. `fac` marks an optional public holiday, which does not guarantee a
day off, so it stays discreet in the grid and OUT of "upcoming holidays".

**THIS LIST DOES NOT UPDATE ITSELF, and it is the only part of the calendar that does not.** The
MOVABLE ones derive from Easter and scale forever; the FIXED ones are LAW written by hand. A new
law, or the city touching a holiday, leaves the grid wrong IN SILENCE. Review it when news of a new
holiday shows up, not by the calendar: 2027 is already covered, because nothing here depends on the
year.

The legal bases:

| Scope | Basis |
| --- | --- |
| `nac` | Law 662/1949, 6.802/1980 (Aparecida), 9.093/1995 (Good Friday), 14.759/2023 (Consciência Negra, national since 2024, NOT just SP anymore) |
| `sp` | State law 9.497/1997 (Revolução Constitucionalista, july 9th) |
| `sc` | Municipal law 7.502/1974 (Corpus Christi), Babilônia 15/08, the city's anniversary 04/11 |

**Two traps the calendar websites fall into and this list does not:**

1. CARNAVAL and CINZAS are neither a national NOR a municipal holiday in São Carlos. They are an
   optional public holiday (state decree 70.273 plus the city hall), hence `fac: true`.
2. CORPUS CHRISTI is a FEDERAL optional public holiday, but a MUNICIPAL holiday here (the law
   above), which is why it goes in as `"sc"` and WITHOUT `fac`. In another city it would be `fac`.

**The check**: the non-`fac` entries add up to 14, which is the number the city hall and the local
press publish for São Carlos. If it ever diverges, that is a sign of a new law.

## The grid's three signals (28/08/2026)

A day cell encodes THREE independent facts, and each one owns a different signal, never one more
color:

| Signal | Meaning |
| --- | --- |
| A solid chip | A holiday, painted with its scope's color |
| An outlined chip | An optional public holiday (`fac`), which stays discreet |
| A ring plus a glow around the whole cell | TODAY |

Today used to be a solid chip in `colAccent`, and it was NOT findable: `accent` and `blue` are the
SAME hex in tokyo-night (`#7aa2f7`) and in catppuccin-mocha (`#89b4fa`), and `blue` is the `sp`
scope, so today was pixel for pixel an SP holiday among the other 20 painted days. The fix is not a
fourth color, which the next palette would collide with again, but a signal no chip uses.

It also stopped OVERWRITING the holiday: the chip is always the holiday's, so 07/09 shows a red
chip inside the ring and Carnaval keeps its outline.

The CURRENT MONTH is the coarse signal, and it works at a different scale: a tinted panel with a
border around the whole block, plus a pill behind the name. The eye lands on the block first and
only then hunts for the ring inside it, which is why the accent on the name alone was not enough,
being too close to `colText`. The panel's padding is what pushed the popover from 880 to 920 wide.

## The calendar's year rollover

`updateClock()` compares the `yyyy-MM-dd` against `calDayKey`, and on the SystemClock's first beat
after midnight it rebuilds. It holds for 01/01 too: `calYear` changes and the whole popover (the
header plus the 12 grids) reevaluates, with no rebuild and no restarting the shell.

MEASURED on 08/08/2026 simulating the 31/12/2026 to 01/01/2027 rollover: a 2027 header, "today" on
01/01, Carnaval painted on 08-09/02. If the machine crosses the rollover suspended, the resume
falls into the same path.

**DO NOT OPTIMIZE THIS INTO MUTATING THE OBJECTS IN PLACE.** The popover reads `calMap` through a
binding (`Repeater { model: bar.monthCells(...) }`), and a QML binding only reevaluates when the
PROPERTY is reassigned: writing inside the existing object (`calMap[k] = v`) emits no signal at
all. The calendar would freeze IN SILENCE: nothing breaks, nothing logs, it just stops rolling the
year over. Measured in headless qml: reassigning propagates, mutating does not.

The calendar popover itself holds no state; `calMap`, `calUpcoming`, `monthCells` and the holidays
live in the Bar and arrive by reference through `bar`, the same contract as the other popovers.

## The workspace click, and the 0.55 dispatch trap

The 0.55 LUA syntax made `dispatch` a shortcut for `hl.dispatch(...)`, so the old form
`("dispatch", "workspace", N)` assembles `hl.dispatch(workspace 3)` and blows up in the parser. The
click died in silence, with nothing on screen.

Careful: `hl.dsp.workspace` is a TABLE, not a function, and calling it gives "attempt to call a
table value". What switches workspaces is `focus`, exactly as in `keybinds.lua`.

## The orphan workspaces of a disconnected secondary (30/08/2026)

Each bar shows ITS monitor's workspaces: 1 to 4 on the primary, 5 to 8 on the secondary. With the
secondary gone, Hyprland gathers 5 to 8 onto the primary (it re-homes them by RULE, see
[`hypr.md`](hypr.md)), but the model was a literal pair of arrays, so those workspaces had NO
button anywhere: a window parked on ws 5 stayed on screen with nothing in the bar pointing at it,
reachable only by SUPER+5.

`wsModelFor` fixes the model at the source: the secondary's bar keeps 5 to 8, and the primary's
shows 1 to 4 plus whichever of 5 to 8 EXISTS while `Theme.secondaryConnected` is false. Existing is
the right test and not "has windows", because Hyprland destroys an empty workspace, so the extra
buttons appear only while there is something to go back to, and the bar returns to four the moment
the secondary comes back.

`Theme.secondaryConnected` reads `Quickshell.screens`, which follows the hotplug, so the whole
thing is a binding and needs no event of its own.

## The tray

A StatusNotifier tray (`TrayStrip.qml`), pinned to the main monitor's right edge. It populates when `qs` is the
watcher, with Waybar gone. Left click activates, middle is `secondaryActivate`, scroll scrolls, and
right opens the native menu.

**Icon path resolution**: some SNIs (Dropbox, for one) publish the icon as
`image://icon/<name>?path=<dir>` in a hicolor theme Quickshell's provider does not resolve. The bar
looks for the real file in `<dir>` and points at `file://`. See [`dropbox.md`](../apps/dropbox.md).

**Positioning the native menu**: the menu is a layer surface, because a PopupWindow receives no
pointer under Hyprland#6682, so it positions itself by SCREEN X and not by `anchor.rect`: the
icon's X inside `barContent` plus the bar's left margin. The Y is implicit, since it sits under the
`exclusiveZone`. See [`quickshell.md`](quickshell.md) for the full TrayMenu reasoning.

**The xembedsniproxy path** (wine/Battle.net, pamac) has no DBusMenu. It was DEAD until 30/07,
because the proxy was not installed, so no icon like that ever came to exist. Quickshell's
`display()` refuses items with no menu ("No menu present"), so the bar fires the SNI's native
`ContextMenu()` through the `tray-native-menu` helper: the proxy forwards the click and the app
draws its own menu at the cursor.

## The session actions (the old power menu)

Lock, darken, log out, suspend, reboot and shut down live in the NixOS Center's footer since
17/10/2026 ([nixos-center.md](nixos-center.md)), with the commands they always had. No sudo:
poweroff, reboot and suspend go through systemd-logind, where an active session is authorized with
no password, and logging out is `loginctl terminate-user`, since LightDM starts a bare Hyprland.

**The lock brings hyprlock up DIRECTLY** (the unit from `lockscreen.nix`) and only then marks the
`LockedHint`. `loginctl lock-session` on its own did NOT lock: it only emits the Lock signal, and
what listened for it was hypridle, so with hypridle stopped by Sunshine's guard the click became a
silent no-op. The `start` is idempotent, so the `lock_cmd` hypridle fires on seeing the signal
duplicates nothing. See [`lockscreen.md`](lockscreen.md).

**Darken** is gamma 0 through hyprsunset, **NEVER dpms**. It restores itself on mouse or keyboard
movement (hypridle's on-resume) or when sliding the brightness. Useful for sleeping with no light in
the room. The dpms prohibition is the same one from [`sunshine.md`](../network/sunshine.md).
