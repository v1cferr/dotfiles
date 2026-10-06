# The glance band on the standing monitor

`modules/home/desktop/quickshell/dash/`. Everything that belongs to the band lives in that one
folder: the panel (`Dashboard.qml`), its pieces (`Tile.qml`, `Horizon.qml`) and the CI script
(`ci-status.sh`, packaged as `ci-status-json` in `modules/home/desktop/quickshell.nix`). It is the top 30% of the standing secondary, reserved so
that no window lands in it.

The band is a part of the Quickshell tree and not a Nix module of its own on purpose: the QML has to
sit under the `mkOutOfStoreSymlink` that becomes `~/.config/quickshell`, or the `root:/` imports
and the hot reload stop working, and it reads every system number from the bar's Scope (`host`).

**Why it exists.** A 27" panel on its pivot is 597 mm tall, so its top third sits ABOVE eye level
for anyone sitting at the desk, while the ergonomic target is 0 to -30 degrees below the
horizontal. A window up there is a neck problem, not a layout preference. The split is 30/70 on
purpose: 768 px of band against 1792 px of work area, on the 2560 logical px that the 1920 px
panel becomes at `scale = 0.75`.

**How the space is taken: `exclusiveZone`, not a gap.** A workspace rule with
`gaps_out = { top = N }` reserves the same strip, and it was the first attempt, but N would then
have to be kept in sync BY HAND with the panel's height, and it only covers the workspaces it
names. A layer surface declares its own height and Hyprland tiles below it, so ONE number governs
both. That number subtracts the bar's own zone (`host.barExclusiveZone`) and the two 4 px margins,
which is what makes the bar and the band together add up to the 30%.

**What earns a place.** The top of a standing screen is for what is read in two seconds and never
clicked: the time, the month, the machine's vitals and what is playing. Everything that takes
a click stays in the 70%. The notification FEED is deliberately not there, only a bell with the
count: a feed in the eyeline is the opposite of a glance surface, so the centre opens on a click
and nowhere else.

**The vitals are tiles, not meter rows.** CPU, RAM, DISK, GPU, TEMP and NET sit in a 3x2 grid
(`dash/Tile.qml`) with a 36 px value, under an `UP · LOAD` line. The first version reused the
popovers' `MeterRow`, whose 10 to 12 px text is sized for a hover a hand away; at `scale = 0.75`
it was unreadable from the chair and left the left column half empty. GPU is power against its
own cap, because the Arc publishes no busy percentage, and NET is download against the link speed.

**No new data.** Every number is already collected in `Bar.qml` for the bar and its popovers, so
the component takes that Scope as `host` and reads it. The month is `monthCells()`, the same
function the year popover renders, at 18 px instead of 9, with the days already gone dimmed so the eye lands on what is ahead.

**The horizon.** The panel's bottom edge is the CPU of the last 2 minutes, in `dash/Horizon.qml`.
It divides the glance zone from the work zone with the one signal worth catching out of the corner
of an eye, instead of with a decorative rule. It is its OWN component and not the shared
`Sparkline`: the band wants a gradient crest, a brighter newest bar and an animated height, and
none of that should follow the widget into the popovers, where a flat bar is the right answer.

It carries a `CPU · 2 MIN` caption because the first person to see it read the shape as audio. A
graph with no label invites the wrong guess, and the label costs 12 px of text.

**Its ceiling follows the peak.** On a fixed 0 to 100 scale an idle desktop at 8% drew a flat line,
so `scaleTop` is the window's peak plus 25%, rounded up to a step of 10, never under 20. The
caption carries that ceiling (`CPU · 2 MIN · 40%`), so a tall bar is never read as a busy machine.

**It SCROLLS, it does not morph, and that is the whole difference.** Animating 60 bar heights on
every sample makes the graph writhe for 220 ms and then sit still, which reads as a stutter even
though nothing is dropping frames (`qs` was at 3% of a core while doing it). A new sample shifts the
data one step LEFT, so the track jumps one step RIGHT at that same instant and walks back over
exactly `sysInterval`, and the pixels never jump: one animated property instead of sixty, and
motion that never stops. The step is `width / (window - 1)` and not `width / window`, because the
track has to be ONE step wider than the viewport or the left edge shows a sliver of nothing at the
start of every cycle.

MEASURED: 3% of a core morphing against 7% scrolling, on a 144 Hz panel. The band is drawing every
frame now, forever, which is what that difference buys. If it ever needs to stop costing that, the
cheap variant is the same slide over 600 ms with the graph at rest for the remaining 1.4 s.

**The date block.** The clock shows HH:mm:ss at one size, then the weekday spelled out, then an ISO
line (`2026-09-15 · Setembro · W38`). The order is deliberate: the weekday is what a person wants
off a clock, and the ISO date plus the ISO-8601 week are the precise record underneath. `isoWeek()`
counts the week against the year its THURSDAY falls in, which is what puts 01/01 on week 53 of the
year before when it lands on a Friday.

**`host` is NOT a required property, and that is not sloppiness.** Quickshell's `Variants` creates
the delegate with `modelData` as the only initial property, so a SECOND required property fails the
creation with `failed to create variant with object` and the layer never appears at all.
