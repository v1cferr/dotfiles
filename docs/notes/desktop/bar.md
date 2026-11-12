# The bar, and its popovers

`modules/home/desktop/quickshell/bar/`. The desktop's bar, the only one; Waybar left in the migration to
Quickshell. It is loaded by `shell.qml` (`Bar {}`), and the popovers live in files next to it.

It shows: the workspaces per monitor plus the focused app's name and Spotifast (Mpris), the NixOS logo (the way
into notifications and the session, [nixos-center.md](nixos-center.md)), the network, the VPN and
Tor, audio (Pipewire), the notification state, the tray and the clock, and on the standing monitor
the operational alerts. The CPU, the disk and a stopped hypridle show only while they need a look;
the weather, the temperatures and the rest of the telemetry are one hover or one click away.

## The continuous strip (11/11/2026)

The bar is ONE frosted strip, 34 px tall, flush with the top of each monitor, and its items sit bare
on it: a glyph and a label, no cell around them. The official logo stands alone on the exact center.
It replaced the mirrored slanted cells of 04/11/2026 (one parallelogram per module), which read as a
row of segments; the owner asked for a quieter, continuous menu bar that keeps every capability.

| Part        | What it is                                                                                                                                      |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| The surface | `colSurfaceBar` (the palette's surface at 72% over the blur), a 1 px `colSheen` row on top, a 1 px `colEdge` row at the foot                    |
| The window  | `BarStrip.qml`, one per monitor: the surface, the geometry, the logo and a region on each side                                                  |
| The regions | `BarLeft.qml` (workspaces, title, media) and `BarRight.qml` (alerts, status, bell, tray, clock), each given its room as one number              |
| The center  | `LogoSlot.qml`: a 40 px slot holding the 20 px logo, 7 px of air above and below it                                                             |
| Controls    | `widgets/Pill.qml`: an icon and a label, with a rounded highlight (24 px tall, the control's 8 px radius) only in the states below              |
| Type, icons | Geist for the text; Material Symbols Rounded, 18 px, outlined, named by ligature (`volume_up`) for the icons ([fonts.md](../hardware/fonts.md)) |

`Bar.qml` keeps what it always held besides the view: the data, the panel coordinator and the IPC.
The band, the NixOS Center and every popover read its root, so the window moved out of it into
`BarStrip.qml` and takes that root as `host`. Nothing reads data twice: the bell reads `Notifs`, the
Center's new buttons call the same functions the bar's items did.

**Every number is an integer.** An item's width is its content plus 8 px on each side, rounded up to
4 px (`Theme.barCellWidth`), so a changing value rarely moves a neighbor, and two highlights stay
4 px apart (`barGap`). The regions start 4 px from the screen's edges, so an item's CONTENT, not
its highlight, sits 12 px in (`barEdge`, the same as Hyprland's `gaps_out` and the band's inset):
the bar's text, the band's cards and the windows share one column.

### Items

Nothing at rest; the accent only while an item's panel is open.

| State                 | Looks                                                                                           |
| --------------------- | ----------------------------------------------------------------------------------------------- |
| rest                  | content alone                                                                                   |
| hover                 | a neutral highlight, `colCellHoverFill` (the palette's text at 12%), `colCellPressFill` pressed |
| open (`selected`)     | `colCellOpenFill`, the accent at 16%                                                            |
| needs a look (`tint`) | the highlight in that state's color at 16%: the CPU pegged, the disk, an operational chip       |
| off by choice (`off`) | content at 55%: muted, VPN down                                                                 |

The highlight fades over `motionHover`, the workspace highlight slides over `motionNormal`, and both
are zero under `my.theme.motion = "off"` ([motion.md](motion.md)). Nothing on the bar animates on its own.

**The logo sits on the screen's EXACT center, and nothing beside it can move it.** Its slot's x is
`floor(width / 2) - 20`, computed from the bar's width alone, never from its neighbors. Each side is
capped at what is left of it before the slot (`leftRoom`, `rightRoom`), so it can never reach it.
`centerLeft` and `centerRight` are the only two numbers the sides read about the center: a center
that grows one day (media, a volume change, a notification) widens those two and nothing else.

## The distribution (12/11/2026)

The main monitor reads `Workspaces, app | the island's room, logo | alerts, network, VPN, tray,
Control Center, clock`, and the standing monitor `Workspaces, app | logo | operational chips`.

**The island lives around the logo** (12/11/2026, [island.md](island.md)). On the main monitor the
sides stop 208 px from the center, whether the capsule shows or not, and the media item left the
strip: a track change is announced in the capsule and its controls are in the Control Center.

**With the Control Center on, what it holds leaves the strip** (12/11/2026,
[control-center.md](control-center.md)). The network keeps its icon and loses its numbers; the VPN
shows only while a tunnel is up or coming up; the sound shows only while muted, as an alert; the
bell is gone, and do-not-disturb turns the Control Center's own icon into its sign. A scroll on
that icon is the volume. With `my.shell.controlCenter.enable = false` the strip is the one of
11/11/2026 again, which is what the next paragraphs about the bell and the fold describe.

**What left the strip, and where it went.** The bar held fifteen permanent cells; secondary
telemetry now waits one hover or one click away.

| It was on the bar     | Now                                                                                                            |
| --------------------- | -------------------------------------------------------------------------------------------------------------- |
| The weather           | the clock's right click, and a card in the NixOS Center; the band still shows it on the LG                     |
| The CPU reading       | on the bar only while pegged (90% and up), tinted; otherwise the Center's cards and the usage panel            |
| The idle toggle       | a button in the Center's header; on the bar only while hypridle is OFF, in `colWarn`, where a click re-arms it |
| The away button       | a button in the Center's header (and its keybinding, unchanged)                                                |
| The time and the date | one clock on the right edge instead of two cells beside the logo                                               |
| The temperature       | already in the Center since 18/10/2026 ([nixos-center.md](nixos-center.md#hardware))                           |

**The alerts are the leftmost items of the right side**, so one appearing or leaving moves nothing
else. The disk shows when the root filesystem is past 90% or under 20 GB free (warning), past 95% or
under 5 GB free (critical), read from the `df` the bar already runs every 30 s; it and the CPU open
the CPU and memory panel.

**The bell exists only while there is a state to show** (`NotifIndicator.qml`): do-not-disturb on
(the struck bell, `colAlert`) or notifications not seen yet (the count, up to `9+`, red when one is
critical). A click opens the NixOS Center under the logo, a right click flips do-not-disturb. The
6 px dot on the logo's corner stays, on both monitors.

**The left side splits its room by rules that read the room alone, never a text.** With a player up
the media takes up to 220 px, the app's name keeps at least 240; with less room the media shrinks
toward 120, then becomes its icon alone, and only then does the name give way, hiding under 120 px
instead of becoming a stub. The workspaces never fold. Without a player the media item is gone and
the name gets its room. Since no level reads a song's text, a track change can never flip one.

**The focused app is named, not its window** (11/11/2026). The bar shows the name the app's
`.desktop` entry carries (`appName` in `Bar.qml`, from the focused toplevel's class through
`DesktopEntries.heuristicLookup`; the class itself when no entry answers), in the strong weight.
Until then it showed the window's title, rewritten with a brand glyph, in sky blue italics, which
changed on every tab and file. The full title is in the hover hint.

**Neutral at rest.** Text and icons are `colText` or `colSubtext`; a color means a state that needs
a look (`colWarn`, `colAlert`, `colCrit`) and the accent means a selection. So a steady link, a VPN
that is up and a playing song stopped being green on 11/11/2026: off by choice is faded content,
and only a link that is slow, unstable or down takes its color.

**The right side folds once, the tray protected.** `measure(level)` in `BarRight.qml` sums the
clock, the tray, the volume, network and VPN, plus the bell and the alerts that are up, from implicit
widths and text metrics that do not depend on the level. When that would cross the logo the
network's numbers and the VPN's name go (the icons and their panels stay). Icons and alerts never fold.

**The tray sits before the clock** (`TrayStrip.qml`), its width from the item count alone (`count`
x 20 px icons and 4 px between them), never from the delegates, and the clock's from a template.
So a throughput or a VPN name changing width moves only what is left of it. No overflow menu was
built: on the ASUS the right side has room for dozens of icons before it folds.

**Popovers.** The calendar and the weather hang from the clock; the NixOS Center, and the panels its
cards open, from the logo; the media panel from the media item (`popLeft`, with no change to
`Mpris.qml`). Every other panel hangs from its own item. A panel stops the screen's inset (12 px)
short of the screen's edges; until 11/11/2026 it could sit flush against one.

**The main monitor gone.** The standing monitor's bar shows the tray at its right edge, the alerts
left of it, only while no screen is wide enough for the full bar (`wideUp`), so the tray never
disappears with the monitor that held it, and is never shown twice.

**Measured on 11/11/2026**, in a second Quickshell on a copy of the tree inside a headless sway
(wlroots `gles2`, a 2560x1440 and a 1080x1920 output, `hyprctl` stubbed, a private D-Bus session),
the tree before the change against the tree after it:

| Check                                                   | Before                        | After                               |
| ------------------------------------------------------- | ----------------------------- | ----------------------------------- |
| The logo's ink, 2560 px output                          | x 1270 to 1289, center 1280.0 | the same; rows 8 to 25, center 17.0 |
| The same, 1080 px output                                |                               | x 530 to 549, center 540.0          |
| The same at 1600 px, a 100-character title and a player |                               | x 790 to 809, center 800.0          |
| First and last ink column, 2560 px output               |                               | 13 and 2547: 12 px from each edge   |
| Idle, six 20 s windows of `/proc/<pid>/stat`, two runs  | 3.65% to 4.95% of a core      | 3.70% to 4.80% of a core            |
| RSS / PSS after about 90 s, two runs                    | 375/295 and 377/293 MiB       | 324/240 and 371/287 MiB             |
| `qs log`                                                |                               | no error, no binding loop           |
| `qs ipc call bar hide`                                  |                               | the 34 rows hold one color          |

The idle cost did not move: both means are 4.1% of a core, inside the spread between windows. The
memory is not a finding either, since the two runs of the new tree differ by more than the trees do.
Opened over IPC and read from captures: the calendar and the weather under the clock, the NixOS
Center under the logo with its two new buttons and its weather card, the bell with a count of 2 (one
critical) and with do-not-disturb on.

**Live since 11/11/2026**, read from captures of the real bars after the merge and a `qs-restart`:
the logo's ink on x 1270 to 1289 on the ASUS (center 1280.0) and 530 to 549 on the LG (540.0), one
`qs-bar` layer of 34 px per monitor and the band on the LG, four tray icons and the workspaces' app
icons drawn, nothing but INFO lines in `qs log`. Two 30 s windows of `/proc/<pid>/stat` 40 s after
the restart gave 6.3% and 6.5% of a core, 314 MiB RSS and 244 MiB PSS, with a song playing and the
network on its rates face. No window was taken on the old bar under the same conditions that day,
so this number says what the bar costs, not whether the change moved it.

Not verified, since nobody drove the pointer: the workspace clicks, hover and the clock's right
click, XEmbed menus, fullscreen windows, Flameshot hiding the bar, a monitor unplugged, and the GPU
cost. Those are the owner's to try at the desk.

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
columns (`tab()` in `Bar.qml`) with U+2007, the space as wide as a digit, and the labels ask for
tabular digits (`Theme.fontTabular`), so the pill keeps its width in a proportional face
([fonts.md](../hardware/fonts.md)); until 11/11/2026 the face was mono and a plain space did it. Before, `431K`
becoming `1.3M` or `9%` becoming `41%` moved every control to their left every 2 s, since the right
cluster is anchored to the edge. Measured on 17/10/2026: the cluster's left edge sat on the same
pixel across six captures 2 s apart while the rates changed.

### The network pill has two faces (03/11/2026)

At rest the pill shows the link's latency (`12 ms`, from the same probe as the panel); while
traffic moves it shows the two rates, in BITS (`↓ 4.9M ↑ 869M b/s`, one unit for both). A permanent `↓ 12K ↑ 8K` was noise most of the day, and at
rest the question is "is the link fine", which the latency answers and the verdict colour of the
icon confirms. It turns busy after 2 samples over 4 Mb/s in either direction and idle after 5
under (10 s), so a page load does not make it flicker. 0.5 Mb/s was the first threshold and this
desk idles between 0.5 and 8 Mb/s (sync, the VPN, a stream), which pinned it on the rates face.

Rates are bits per second, SI (`fmtBits` in `Bar.qml`), because the ISP plan and every speed test
are written that way: `108.6M` in bytes had to be multiplied by 8 in the head to be compared with a
"1 giga" plan. Volumes (moved, since boot) stay in bytes, which is how files are counted.
Each face is padded on its own, and the row's width maths measures whichever is showing.

## Contextual expansion: one panel at a time (17/10/2026)

Every panel the bar opens on hover (weather, calendar, temperature, usage, network, VPN statistics)
goes through ONE coordinator in `Bar.qml` and one window type, `bar/BarPanel.qml`. It replaced four
separate hover machines that each kept their own "pill hovered", "popover hovered" and close timer.

| Gesture                            | What it does                                                                                              |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Hover                              | after 200 ms of rest (`Theme.hoverIntent`) the panel opens; a pointer only crossing the bar opens nothing |
| Hover a neighbor                   | its panel takes over at once, with no new wait                                                            |
| Leave                              | 300 ms of slack to cross the gap into the panel, then it closes                                           |
| Click                              | PINS it: it stays without the pointer, and its pill stays lit                                             |
| Click again, click outside, Escape | closes the pinned panel                                                                                   |
| Click another pill                 | switches the pin to that panel                                                                            |
| Scroll                             | unchanged (volume, media)                                                                                 |

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
`Theme.bandTop` (the bar's 34 px and 8 px more), so it lands the same 8 px under the
bar on both monitors; relying on the reserved zone would drop it under the whole glance band on the
standing monitor, whose bar reserves the band's strip ([dash.md](dash.md)). The media panel follows
the rule too, hung under its pill through `qs ipc call mpris toggleAt <x>`.

**One click changed meaning**, and its old action moved to the right click: the network's
`nm-connection-editor`. The weather's forecast site, which had moved the same way, left with the
weather's pill on 11/11/2026; the clock's right click opens the weather panel instead.

**Tested on 17/10/2026** with a virtual pointer and keyboard (`wlrctl` and `wtype` from nixpkgs, not
installed), reading the mapped `qs-panel` layers after each step: nothing at 80 ms of hover and the
panel at 500 ms; the neighbor's panel at 80 ms; closed 500 ms after leaving; pinned and still there
600 ms after the pointer left; closed by Escape; switched by a click on another pill; closed by a
second click; closed by a click on the glance band; the volume hint shown 100 ms after leaving the
weather's panel; the power menu closing a pin.

## Checking without a mouse (the IPC handler, 18/10/2026)

`qs ipc call bar panel <key>` opens a panel PINNED by its coordinator key (`weather`, `cal`, `usage`,
`net`, `temp`, `center`, and `ops-ci`, `ops-svc`, `ops` on the standing monitor's bar): the calendar
and the weather under the clock, every other under the logo; `qs ipc call bar close` closes whatever
is open. It checks a panel's content and glass, not its anchor under the pill. `qs ipc call notif expand` and `collapse` open or fold every group in the
NixOS Center's history. Never during a fullscreen game: a pinned panel takes a focus grab.

## Hiding the bar (the IPC handler)

It exists because of Flameshot's overlay: on Hyprland a normal WINDOW never covers a `top` layer,
and the bar lives in one, so the overlay shows a FROZEN frame that already contains the bar and the
LIVE bar draws on top, giving the "duplicated bar" effect. There is no window rule that solves it
(an open feature request, hyprwm/Hyprland#4847), so the only path is hiding. See
[`flameshot.md`](../apps/flameshot.md).

`visible: false` unmaps the layer surface, so the 34 px strip stops capturing clicks, which matters
for selecting a region at the top of the screen.

**Do NOT name the handler "show"**: it collides with the `qs ipc show` subcommand and the CLI never
calls the function. The same trap is documented in `shell.qml`, in the vpn `IpcHandler`.

## The workspace rail (18/10/2026, bare since 11/11/2026)

`WorkspaceStrip.qml`, the ADAPTIVE WORKSPACE RAIL: each monitor's workspaces as two-digit numbers
(`01` to `04` on the ASUS, `05` to `08` on the LG), bare on the strip, every number one width
measured from `00`, the active one under one rounded highlight that slides (24 px tall, the
control's 8 px radius).

| State                              | Looks                                                             |
| ---------------------------------- | ----------------------------------------------------------------- |
| active                             | accent number on the sliding highlight (`colCellOpenFill`)        |
| occupied                           | `text` number in the strong weight, and its apps' icons           |
| empty                              | `dim` number                                                      |
| a window opened there              | a steady 8 px yellow tick under the number (`colWarn`)            |
| a window there asked for attention | the highlight in `colCrit` at 22%, the number in red              |

**The apps.** Each number carries its apps' icons, always. For a few minutes on 11/11/2026 they
opened only on a rested hover, to make the rail quieter; the owner tried it live and preferred
seeing them, so that went back the same day. The icons are one per window class in
Hyprland's order (`wsApps` in `Bar.qml`, read from the toplevels' IPC object), up to three (two on
the LG's narrower bar) and then `+N`: full color on the active workspace, greyed on the others (`widgets/AppIcon.qml`, the same
lookup the lock screen uses. A Steam game's class says nothing (`hl` for Northgard,
`steam_app_<id>` under Proton), so `data/SteamIcons.qml` reads `SteamAppId` from the window's
process, once per pid, and shows the `steam_icon_<id>` Steam installed. A Wine app has no .desktop
entry, so `data/WineIcons.qml` falls back to the icon Bottles extracted, `<bottle>/icons/<Program>.png`, matched by the program's name and
then by its executable in `bottle.yml`). An app with several windows there gets one 4 px mark per window
under its icon, up to three (accent on the active workspace, `subtext` on the
others): no width, so a second window never moves the rail. A click on an icon focuses that app's
window (`hl.dsp.focus({ window = "address:0x..." })`, with `cursor.no_warps` on for that one call so
the pointer stays on the bar); with several, each click focuses the next one, wrapping, and from
another app the most recently used (`focusHistoryID`). A click elsewhere on the number switches
workspace as before. The toplevels are refreshed at start and when a window opens, closes or moves, so the
icons follow.

The two marks used to be one, and pulsed forever. They are apart, since a window that merely opened
is news and an urgency is a request (`wsActivity` from the window count, `wsUrgent` from Hyprland's
`urgent` event), and steady: visiting the workspace clears both. A hover shows a tip with the window
count and each app, with its own count past one (`code · 5 windows`): the slants stop at three,
so the exact number lives there. The keybinds, the orphans of a gone secondary and the slide are
unchanged.

## The standing monitor's bar: status first

`compact` reads the panel's own WIDTH, below 1600 px, and not "is this the secondary", so rotating
the monitor back restores the full bar with no config change (rule 3). On the 1080 px LG the bar
keeps the logo at x 540 and holds:

- **Left:** that monitor's workspaces, and the window title when it fits cleanly.
- **Right:** the operational alerts (`OpsIndicator.qml`) and nothing else. No clock: the band right
  under it shows the time at 72 px. Nothing the band's cards already show is repeated. The one
  exception is the tray, and only with no wide screen up ([the distribution](#the-distribution-12112026)).

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

| State    | Chip                    | Means                                                                         |
| -------- | ----------------------- | ----------------------------------------------------------------------------- |
| healthy  | nothing but a dim check | every source answered and nothing is wrong                                    |
| failing  | `󰅚 CI · 2` red          | two current failures across GitHub and the FAI GitLab                         |
| running  | `󰑮 CI · 1` neutral      | nothing failing, one run in progress                                          |
| degraded | `󰀪 SVC · 1` orange      | a service with fewer units running than expected                              |
| failing  | `󰅚 SVC · 1` red         | a service down                                                                |
| stale    | `󰥔 CI · 2` dim          | a forge answering only with old data: the count is its LAST KNOWN one         |
| unknown  | `󰋗 CI · ?` dim          | a forge never read, or the services meta silent for two minutes               |
| folded   | `OPS · 3`               | both sources, in the worse state's colors, when the room is too small for two |

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

The date and the time are ONE item on the main monitor's right edge, after the tray (11/11/2026;
from 18/10/2026 they sat in two cells on each side of the logo): `qua 11/11  20:00`, in `text`, its
width measured from today's date and a template time in tabular digits, so a new minute moves
nothing and a new day at most once. The SECONDS are not on the bar: `timeStr` keeps `HH:mm:ss` for the band's big clock, and
the bar reads `dateStr` and `barTimeStr`, which change once a day and once a minute. Never on the
standing monitor (the band shows it). A hover or a click opens the calendar, hung from the clock; a
right click opens the weather panel, since the weather left the bar.

The weekday comes from local `dowAbbr`, as every spelled weekday or month does (the calendar, the
band, `monAbbr`), NOT from Qt's `"ddd"`, which follows the
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

| Panel              | Verdict           | Graph                                                    | Provenance                              |
| ------------------ | ----------------- | -------------------------------------------------------- | --------------------------------------- |
| `UsagePopover.qml` | idle to stalling  | the CPU over 2 min, plus one bar per thread              | the CPU model, cores/threads, uptime    |
| `TempsPopover.qml` | cool to critical  | the hottest sensor over 2 min                            | how many sensors, and from which chips  |
| `NetPopover.qml`   | offline to steady | throughput mirrored over 2 min (log), latency over 1 min | the interface, its type, who manages it |

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

**Network.** The throughput graph is MIRRORED around one axis, download growing up and upload down,
sharing ONE scale. Two scales would be prettier and would lie about which direction is bigger.

The scale is LOGARITHMIC since 03/11/2026. On the linear one, a single 80 MB/s burst set the
ceiling for the whole two minutes and every 12 KB/s sample came out as 0 px, so the graph was a flat
line with one spike: it showed the burst and hid the link. A link idles at kilobytes and bursts at
tens of megabytes, three or four orders apart, and a log axis gives both a readable height while
keeping the order right.

The axis is FIXED since the second round (03/11/2026): 1 kb/s at the center line to the link at
the edge (the port's 1 Gb/s, or the last speed test when that is higher). The first version put the
ceiling one step above the window's peak, so it moved with every burst, and the user's capture
showed the cost: ↓5 Mb/s and ↑870 Mb/s at nearly the same height, because each frame had its own
scale. A fixed axis reads like a dB meter: two labelled grid lines (1M and 100M, the labels on the
axis side so they never stack) are always in the same place, the eye learns the positions, and a
dashed line per half marks the last measured capacity. The honest number is still beside the
graph: the current rate and its share of the plan (`of plan ↓0% ↑88%`, against the speed test, not
the port). An area with a stroke
replaced the bars: 60 two-pixel bars on a log axis read as noise, a curve reads as a level.

Around the graph: the current rate in the direction's colour, the window's peak, and the hover
with both directions and the time of the sample. The volume the window moved went under "Since
boot" in the facts grid, where the other byte counts are. While the window is still filling after a reload the legend says so ("filling · 20s of
2 min") instead of passing a short window off as the whole.

**The latency is a graph too**, the probe's own 60 samples, drawn like the VPN's (linear from zero,
60 ms floor, a lost packet as a full red bar), with the mean, the jitter and the loss in one line
over it. Three rows of single numbers became one line and a shape. Link, address, gateway and the
since-boot traffic went into a two-column grid of label-over-value: they are looked up, not
compared, and the panel lost a third of its height.

**Which apps are moving the bytes** comes from `nethogs -t`, the one tool that maps a socket to its
process per refresh. It needs to capture packets and to read every process's sockets, so it is a
`security.wrappers` entry (`modules/nixos/network/nethogs.nix`) with exactly those four
capabilities (`net_admin`, `net_raw`, `dac_read_search`, `sys_ptrace`), executable by `wheel`
only, and never a root daemon. It runs ONLY while the panel is open (the Process is bound to the
panel's `visible`), so the capture costs nothing the rest of the time. Rows are grouped by program
name, the top five, and anything under 1 KB/s is left out, so "nothing moving" is an answer and not
an empty block. Without the wrapper the panel says "nethogs unavailable" instead of hiding the
section.

**The public address** (03/11/2026) is asked to `1.1.1.1/cdn-cgi/trace`, the same anycast anchor as
the probe, once over IPv4 and once over IPv6; the answer also names the Cloudflare site that saw it
(`GRU`), which is where the traffic actually leaves. The IPv4 is the router's WAN behind NAT and
nothing local can know it; the IPv6 is this machine's own global address, shown in full on its own
line because a 39-character address does not fit beside anything. It is asked ONLY when the panel
opens, at most once per 5 minutes, and again at once if the local address or the gateway changed:
a new network is a new public address.

### The speed test (03/11/2026)

`net-speedtest` (`modules/home/services/net-speedtest.nix`) wraps Ookla's official CLI, which opens
several connections at once and so measures a gigabit line right where `speedtest-cli` does not. The
panel's button and a user timer every 6 h run the SAME script and append to the same
`~/.local/state/net-speedtest/history.jsonl`, one trimmed line per run (bandwidth in bytes per
second, as Ookla gives it). A `flock` makes the second of two overlapping runs answer
`{"type":"busy"}` and leave, and a cancel stops Ookla by its PID, never by process group, because
the caller can share ours. The test runs on the default route's interface, so the VPN never carries
it.

**Three latencies, three questions.** The probe's number (12 ms) is ICMP to 1.1.1.1 at 1 packet/s,
the IDLE round trip to the internet past the ISP. Ookla's ping (7 ms) is to its chosen server, often
a few hops away, so it is lower and is not the same question. Ookla's loaded latency (17 ms while
downloading) is the round trip while the link is saturated: when it climbs far above idle, the
router is queueing (bufferbloat), which is what freezes a call during a download.

**In the panel** (`bar/SpeedTestSection.qml`), under the probe's latency: the last result in the
direction colours, its ping, its loaded latency per direction, loss and server, and the last 12 runs
as bars with their date on hover. The loaded line turns peach when the test ADDED more than 30 ms
over its own ping, the point where the bufferbloat tests stop grading a link as good. ▶ runs the
same `net-speedtest --progress`, and while it runs the section becomes one bar of three thirds
(latency, download, upload, so it never runs backwards) with the live rate, and the throughput
graph above shows the saturation as it happens. ■ cancels. A run that finds the timer's test
holding the lock says so instead of failing.

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
panel of their own (the clock, a pegged CPU, VPN, network) already did; the rest (the
window title, Spotifast, volume, the bell, a stopped hypridle, the disk and each tray icon) get
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

| Method             | mdev   | peak    | loss resolution  |
| ------------------ | ------ | ------- | ---------------- |
| 3 packets in 0.6 s | 0.4 ms | —       | 33% (3 packets!) |
| a 20 s window      | 3.3 ms | 54.7 ms | —                |

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

The weather's ICON derives from the integer `weather_code`, NEVER from the label. It used to regex the
en-US prose, so translating the label to pt-BR would have turned every icon into the default cloud
in total silence. That trap, the 4-degree disagreement with the lock screen that motivated the
SSOT, and the measured failure paths are in [`weather.md`](weather.md).

## The calendar

Since 18/10/2026 the calendar is its own subject: the verified holiday registry, the year and month
views, the filters and the source checks are in [calendar.md](calendar.md). What stays here is its
contract with the bar: the clock opens it, hung from the clock; `calYear`, `calTodayM`
and `calTodayD` live in the Bar and roll over on the SystemClock's first beat after midnight
(`updateClock()` against `calDayKey`), which the panel and the band's month card both follow.

**Reassign, never mutate.** A QML binding only reevaluates when the PROPERTY is reassigned: writing
inside an existing object emits no signal, and the calendar would freeze in silence. The registry
model keeps the rule: `Holidays.filters` is replaced on every toggle, and `calMap` is a binding.

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

**The lock brings the lock screen up DIRECTLY** (`lockscreen.service`) and only then marks the
`LockedHint`. `loginctl lock-session` on its own did NOT lock: it only emits the Lock signal, and
what listened for it was hypridle, so with hypridle stopped by Sunshine's guard the click became a
silent no-op. The `start` is idempotent, so the `lock_cmd` hypridle fires on seeing the signal
duplicates nothing. See [`lockscreen.md`](lockscreen.md).

**Darken** is gamma 0 through hyprsunset, **NEVER dpms**. It restores itself on mouse or keyboard
movement (hypridle's on-resume) or when sliding the brightness. Useful for sleeping with no light in
the room. The dpms prohibition is the same one from [`sunshine.md`](../network/sunshine.md).
