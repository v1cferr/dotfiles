# The bar, and its popovers

`home/desktop/quickshell/bar/`. The desktop's bar, the only one; Waybar left in the migration to
Quickshell. It is loaded by `shell.qml` (`Bar {}`), and the popovers live in files next to it.

It shows: the workspaces per monitor plus the title, the clock, cpu/ram/disk/temp, the GPU, audio
(Pipewire), Spotify (Mpris), the network, the VPN, the weather, the tray, notifications.

## Hiding the bar (the IPC handler)

It exists because of Flameshot's overlay: on Hyprland a normal WINDOW never covers a `top` layer,
and the bar lives in one, so the overlay shows a FROZEN frame that already contains the bar and the
LIVE bar draws on top, giving the "duplicated bar" effect. There is no window rule that solves it
(an open feature request, hyprwm/Hyprland#4847), so the only path is hiding. See
[`flameshot.md`](flameshot.md).

`visible: false` unmaps the layer surface, so the 30 px strip stops capturing clicks, which matters
for selecting a region at the top of the screen.

**Do NOT name the handler "show"**: it collides with the `qs ipc show` subcommand and the CLI never
calls the function. The same trap is documented in `shell.qml`, in the vpn `IpcHandler`.

## The clock

The time AND the date are ALWAYS visible, in the same pill. It used to be a toggle on click: one or
the other, and to see the date you had to click twice, there and back. The time comes first and the
date goes into the Pill's `sub`, in a discreet color. A hierarchy, not a separation.

The weekday comes from a local `dowAbbr` and NOT from Qt's `"ddd"`, because Qt's format depends on
the PROCESS' locale, so "sáb" would become "Sat" if the bar came up with no `LC_TIME`. There is no
year; whoever needs it has the calendar on hover.

## The GPU reading

Intel Arc B580 on the `xe` driver: the temperature comes through hwmon, and the usage % does NOT
exist on xe, so it is 0. The output is `"0,<temp>"` for `parseGpu`, which was nvidia-smi's
`"usage,temp"` back on Arch.

## The VPN: three surfaces, one source

`vpnList` holds the RAW list `[{id,name,connected}]` because the popover needs one row per VPN;
`vpnConnected`/`vpnName` remain the aggregate the pill shows. A single read feeds both.

That matters: rofi used to reassemble the labels on its own with `systemctl is-active`, which LIES
during nxBender's crash loop, saying "active" with no tunnel existing. See [`vpn.md`](vpn.md).

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
  jitter, loss, traffic and uptime. It has nothing to click, the same criterion as the calendar and
  the metrics popover.

Both anchor at the SAME point of the bar, so the Bar hides the stats one while the actions menu is
open; otherwise one would draw on top of the other, since the mouse stays over the pill the whole
time.

Right click on the pill is still the shortcut for taking everything down.

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

**WHAT DISCOVERS THE TARGET is the CLI** (`system/net/vpn.nix`): sweeping routes and testing
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

## The tray

A StatusNotifier tray with a single background for the icon group. It populates when `qs` is the
watcher, with Waybar gone. Left click activates, middle is `secondaryActivate`, scroll scrolls, and
right opens the native menu.

**Icon path resolution**: some SNIs (Dropbox, for one) publish the icon as
`image://icon/<name>?path=<dir>` in a hicolor theme Quickshell's provider does not resolve. The bar
looks for the real file in `<dir>` and points at `file://`. See [`dropbox.md`](dropbox.md).

**Positioning the native menu**: the menu is a layer surface, because a PopupWindow receives no
pointer under Hyprland#6682, so it positions itself by SCREEN X and not by `anchor.rect`: the
icon's X inside `barContent` plus the bar's left margin. The Y is implicit, since it sits under the
`exclusiveZone`. See [`quickshell.md`](quickshell.md) for the full TrayMenu reasoning.

**The xembedsniproxy path** (wine/Battle.net, pamac) has no DBusMenu. It was DEAD until 30/07,
because the proxy was not installed, so no icon like that ever came to exist. Quickshell's
`display()` refuses items with no menu ("No menu present"), so the bar fires the SNI's native
`ContextMenu()` through the `tray-native-menu` helper: the proxy forwards the click and the app
draws its own menu at the cursor.

## The power menu

A taskbar-style "Start button": the NixOS logo in the bar's top left corner, opening lock, log out,
suspend, reboot and shut down. No sudo: poweroff/reboot/suspend go through systemd-logind, where an
active session is authorized with no password, and logging out goes through uwsm.

**The lock brings hyprlock up DIRECTLY** (the unit from `lockscreen.nix`) and only then marks the
`LockedHint`. `loginctl lock-session` on its own did NOT lock: it only emits the Lock signal, and
what listened for it was hypridle, so with hypridle stopped by Sunshine's guard the click became a
silent no-op. The `start` is idempotent, so the `lock_cmd` hypridle fires on seeing the signal
duplicates nothing. See [`lockscreen.md`](lockscreen.md).

There is also a "darken the screen" action: gamma 0 through hyprsunset, **NEVER dpms**. It restores
itself on mouse or keyboard movement (hypridle's on-resume) or when sliding the brightness. Useful
for sleeping with no light in the room. The dpms prohibition is the same one from
[`sunshine.md`](sunshine.md).
