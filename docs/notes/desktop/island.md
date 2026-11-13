# The island: one thing at a time, around the logo

`modules/home/desktop/quickshell/Island.qml`, `island/IslandMath.qml` and `bar/IslandSlot.qml`. A
capsule that grows out from behind the NixOS logo on the main monitor's bar, says one thing, and
goes. With nothing to say it is not there: the logo stands alone. While media plays it rests open,
with the cover, the title and a wave of what is heard.

Before 12/11/2026 the same events lived in three places: a bottom OSD for the volume, the
microphone and the brightness, toasts in the top right corner for notifications, and a media item
on the bar's left. A VPN coming up showed nowhere until it was up, and a Bluetooth device
connecting showed nowhere at all.

## What it shows

Lower is more urgent. A level the user is setting beats a result, which beats news.

| Priority | Event                                     | Stays                | Comes from                                    |
| -------- | ----------------------------------------- | -------------------- | --------------------------------------------- |
| 1        | The root filesystem about to fill         | until it is answered | the bar's `df` (95% used or under 5 GiB free) |
| 3        | Volume, mute, microphone, brightness, DPI | 1.5 s                | `osd/Osd.qml`, which keeps its anti-flash arm |
| 4        | A VPN connecting, then its result         | while it tries; 4 s  | the bar's VPN phases                          |
| 5        | A plain notification                      | 5 s                  | `Notifs.qml`                                  |
| 6        | A Bluetooth device connected or gone      | 3 s                  | `Quickshell.Bluetooth`                        |
| 8        | Media playing: the cover, artist, title   | while it plays       | `Media.qml`                                   |
| 9        | Apps with notifications not seen yet      | until they are seen  | `Notifs.qml`                                  |

Priority 2 is not an event: it is the pointer. While it rests on the capsule the clock stops and
only a priority 1 event may take the place.

## The rules

They are `IslandMath.qml`, pure functions tested by `tests/tst_island.qml`:

- **A more urgent event interrupts.** What it interrupted comes back once, if it had more than a
  second left; interrupted again, it does not. An event with no end (a VPN still connecting) always
  comes back, since it is a state and not a moment.
- **The same event updates in place.** The volume still moving, or a VPN reaching its result, is
  one event whose content changes; its clock restarts and nothing re-enters. Notifications share
  one key too: of a burst, the capsule holds the last, and the others are in the NixOS Center.
- **A less urgent event waits**, in a queue of three moments: one per key, and past three the
  least urgent leaves. An event with no end is not a moment and never leaves that way.
- **Media is a state.** It is the least urgent thing the island holds and has no end: there while
  something plays, updated in place by a new track, gone on a pause. Everything else takes its place
  and it comes back, by the rule above for an event with no end. Until 12/11/2026 a new track was a
  four-second moment and what played was nowhere on the bar.
- **The pointer freezes it.** Leaving gives back what was left, never less than a second.
- **One timer, set for the next deadline.** Nothing polls; with nothing shown, nothing runs.

## Where it lives

The capsule is an item inside the bar's own window, drawn under the logo: no layer of its own, no
second blur, and it never takes the keyboard, since it is not a window. The logo is not part of it
and does not move: on 12/11/2026, with a notification and then a brightness change showing, the
logo's ink stayed centered on x 1280.0.

The sides of the bar stop 208 px from the screen's center (`Theme.islandHalf`) whether the capsule
shows or not, so an event never moves a workspace or an icon. The capsule is symmetric: both sides
take the width of the wider one, an icon and a name left of the logo, a level and a word right of
it, each eliding past its room.

With media playing or notifications not seen yet, the capsule OPENS downward on a hover, and a
click keeps it open ([open](#open)). On anything else a click leads to the surface that holds the
rest, a level or a VPN to the Control Center, and the disk warning is dismissed by its click.

It exists only on the main monitor's full bar. With no screen wide enough for it (`Island.live`),
the OSD and the toasts do what they always did, so no event is ever sent to a capsule nobody sees.

## The apps that wait

A notification shows with the icon of the app it came from, in the place of the bell: whose it is
reads before its words do. And while notifications wait to be seen, the apps they came from rest
in the capsule, up to three icons and a `+N` (12/11/2026, asked for with WhatsApp's messages as
the example):

- With nothing else to show, the capsule holds `3 new` left of the logo and the icons right of it.
- While media plays, the icons sit at the far end, after the title. Unseen apps are the least
  urgent thing of all (priority 9, no end), so they never hide what plays.
- The open island lists the three newest of them as the same cards the NixOS Center uses
  ([open](#open)).
- Seeing them there does not mark them seen. `Mark as seen` under them does, and so does opening
  the NixOS Center, by the row beside it. A notification that is dismissed or expires leaves the
  list by itself.

`Notifs.qml` owns the list (`unseenList`, and `unseenApps`, one entry per app, newest first); the
count on the logo's dot is the same number.

**Whose icon.** The app's `.desktop` entry first (`widgets/AppIcon.qml`). An app no entry answers
for wears what its notification brought (`Notifs.appIconOf`): a theme icon's name, a file's path,
or image data, in that order, and never a chat message's picture, which is a contact and not the
app. The first version looked at the entry alone, and on 12/11/2026 Sunshine and Zen rested in the
capsule as the neutral glyph while the list right under it drew their icons: the card read the
notification, the capsule did not. Both read one rule now.

## The wave

The capsule is symmetric, so a title wider than the artist left a gap beside the cover. Since
12/11/2026 a wave of what is heard takes it, asked for as "really synchronized with the audio",
and then as cleaner, more fluid and lighter than its first version.

- **It is the real spectrum.** `Audio.qml` runs [cava](https://github.com/karlstav/cava) as a
  child process with `media/cava.ini`: it reads what is heard and prints 24 levels a frame, bass
  first, 24 frames a second, already smoothed and scaled to what plays. `widgets/Wave.qml` only
  draws them: bars that rise and fall in place, 3 px wide, with no clock of their own.
- **The bass is by the cover** in the capsule, and the treble at the far end; the bars between
  read between two bands, so five bars or twenty show the same shape.
- **Only while it is seen.** cava runs while media is what the capsule shows, or while the media
  panel is open. A volume key or a notification takes the capsule for a moment, so cava outlives
  the asking by 8 s instead of starting again each time; a pause ends it. With
  `my.theme.motion = "off"` there is no wave and the gap is back, and the same on a host where
  cava is not installed yet.
- It takes what the wider side leaves, and never fewer than five bars.
- It hears the default output, not the player alone: a notification's sound moves it too.

**Why cava and not Quickshell's own meter.** The first version (the same day) was a level over
time from a `PwNodePeakMonitor`, chosen for needing no package. It reports once per audio quantum
on the shell's main thread, and a game or a Sunshine stream holds the quantum at 256 frames: 185
reports a second. Measured on 12/11/2026, three windows each:

| Where                       | Without a wave | The peak meter   | cava                              |
| --------------------------- | -------------- | ---------------- | --------------------------------- |
| Harness, quantum 256 (game) | 5.27% to 5.80% | 10.00% to 12.93% | not run                           |
| Harness, quantum 2048       | 4.20% to 4.93% | 6.80% to 7.47%   | 4.73% to 5.53% at 20 frames       |
|                             |                |                  | 5.40% to 6.33% at 30 frames       |
| cava's own process          |                |                  | 0.53% to 0.90%, at either quantum |

All of a core, the shell's process unless said. The live shell with the peak meter and a game open
took 13.47% of a core and 1.46% of the GPU's render engine over 15 s, so the weight was the CPU's.
cava's cost does not follow the quantum, and its smoothing is what the hand-made scale of the
first version was reaching for: that one needed three tries (against the loudest, squared, then
between the loudest and the quietest) to look right on both a dense track and a sparse one.
24 frames sits between the two measured rates.

**Live, after the rebuild**, the same day, three 15 s windows with a video playing and no game
open: the shell took 7.73% to 8.60% of a core and 1.78% to 1.99% of the GPU's render engine, and
cava 0.47% to 0.53% of a core. cava's own stream asks for a quantum of 512 frames, so the audio
graph runs at 512 while the wave shows, where it would idle at 1024 or more.

## Open

The island has three sizes of ONE shape (12/11/2026). It was asked for in two steps the same day,
with the Dynamic Island's three presentations and the notch apps of macOS (boring.notch,
NotchNook) as the picture: first "the whole capsule one hover zone, opening downward", then "the
whole NixOS Center as an island that adapts". Before, a hover on the media opened a card under the
bar, a hover on the apps' icons another, and the logo's click a third, each a separate surface.

| Size        | How it comes                                              | What it shows                                    | How it goes                          |
| ----------- | --------------------------------------------------------- | ------------------------------------------------ | ------------------------------------ |
| At rest     | always                                                    | the capsule, or the logo alone                   |                                      |
| The summary | the pointer resting on the capsule, with media or unseen  | what plays, and the three newest unseen          | 400 ms after the pointer left it     |
| Full        | a click on the logo or the capsule, SUPER, `notif toggle` | the NixOS Center, what plays right under its top | the logo again, a click outside, Esc |

- **One shape, two windows.** The head is the capsule, in the bar's window: open, it is as wide
  as the island gets (416 px), opaque, and reaches the bar's foot with its lower corners squared.
  The body is `bar/IslandDrop.qml`, a layer that starts where the bar ends. Both are
  `Theme.colIsland`, opaque, because glass over two different backdrops would show where they meet.
- **One outline** for the body (`QtQuick.Shapes`): for the summary a column as wide as the head;
  for the Center 520 px, a SHOULDER 52 px past each side of the head, which leaves 8 px under the
  bar and joins the head by a curve. The Center keeps its 520 px layout and no bar item moves; the
  curve and the shoulders are inside the body's window, off the bar's items.
- **Always mapped, empty while shut.** The body's window exists from the start, zero tall and
  taking no pointer (its mask is the body), so opening is the island's own motion from its first
  frame: no layer to map, no fade of the compositor's over it. It is shown one turn of the event
  loop after it is made, never at once: on 12/11/2026 the first hot reload after it went live
  crashed the shell in `QWindow::setScreen` (Quickshell 0.3.2 restarted itself, and the
  notification history in memory was lost). A stand-in window of ten lines, visible from its
  first instant, did the same on every reload in the harness; shown a turn late, six reloads in a
  row passed, one of them with the Center open.
- **Full opens with nothing in the capsule too**: the head grows out of the logo and the body
  comes down. From the summary it grows in place, taller and out at the shoulders.
- **The keyboard only at full size.** The summary never takes it from the window under it.
- **The hover.** The pointer resting on the capsule for `Theme.hoverIntent` opens the summary; the
  zone is the capsule's width from the screen's top edge to the bar's foot, so a pointer thrown at
  the top of the screen lands on it. A pinned panel is never taken down by a hover, and the summary
  opens only on media playing or notifications not seen.
- **Every strip has the head.** The island rests only on the main monitor, but the other
  monitor's logo opens the Center there in the same shape, the head drawn while it is open.
- **Who decides.** Full is the bar's coordinator's `center` pin, as the Center always was
  ([nixos-center.md](nixos-center.md#how-it-opens-and-closes)); `Island.qml` follows it (`full`)
  and owns the rest (`open`, the two hovers, `where`). `qs ipc call bar island open` and `close`
  hold the summary with no pointer, and `bar islandReach` says how far the body reaches, in px.

| Part                 | Motion                                                                   |
| -------------------- | ------------------------------------------------------------------------ |
| The head widening    | the capsule's spring, held at the island's width (no overshoot there)    |
| The body coming down | the same spring on its height; what it holds is revealed, not squeezed   |
| A long way down      | past 400 px the spring is damped at 0.45 instead of 0.37: it settles     |
| The shoulders        | the spring on their reach, out with the Center and back with it          |
| What it holds        | two beats 80 ms apart; the summary and the Center trade places by a fade |
| Shutting             | an ease-out over `motionHover`; the head narrows when the body is gone   |

**Measured on 12/11/2026** in the harness, every state driven over IPC:

- The summary's spring: the body passed its 269 px by 9.7 px (3.6%) and was within half a pixel
  of rest after 352 to 374 ms; shutting took 112 ms over 8 frames.
- The Center's: with the island's own damping its 953 px were passed by 38.9 px, more than the
  slack under it. Three dampings were traced: 0.70 took 922 ms to rest, 0.55 took 655, and 0.45
  passed by 0.9 px and rested in 425 ms, halfway down at 88 ms and nine tenths at 185. 0.45 it is.
- The seam: on the rows where the two windows meet (y 33 and 34) the fill is the same color and
  the outline runs from x 1072 to 1487 on each. The body's hairline is drawn by the outline and
  comes out one or two levels off the head's (46,50,73 against 47,52,74), and one row lighter
  where the curve to the shoulder begins.
- Symmetry about the logo (x 1280): head 208 px each side in every size; the summary's body 208;
  the Center's 260, and 256 on the row through its shoulders' corners. On the second monitor
  (center 540): head 202 and body 258 each side, counting the fill alone.
- Opening the Center from the second monitor's logo left the main monitor's capsule as it was.
- Cost, with the machine loaded that evening (load average 25), two 12 s windows each: 20.75% to
  21.42% of a core on the tree before, 19.42% to 20.33% on this one with the island never opened,
  21.58% to 21.83% after the Center was opened once and shut. Earlier the same day, quiet, the
  summary alone: 6.80% to 7.47% shut against 7.27% to 7.67% before, and 10.73% to 11.47% open on
  what plays.

## The media card

`media/MediaCard.qml` is what plays, to look at and to drive. The open island shows it, and so
does the media panel (`media/Mpris.qml`), a window of its own for the bar's media item where the
island is off and for `qs ipc call mpris toggle`. It was redrawn on 12/11/2026, asked for with a
capture of the old one: that still had the mono font, since it named none, Nerd glyphs in
outlined rings, and the artist twice.

| Row        | What                                                                                        |
| ---------- | ------------------------------------------------------------------------------------------- |
| The track  | a 72 px cover; the title, the artist, and the album or else the player's name               |
| The wave   | the island's, across the card and mirrored: the bass in the middle, the treble at both ends |
| The seek   | a 4 px track; a press or a drag moves the track there; the two times under its ends         |
| The keys   | previous, play or pause (filled), next: centered, so under the logo                         |
| The volume | of what plays: the player's own stream when it is known, else the output's                  |

At the track's right end a key goes to the window it plays in (`Media.reveal`): the player's app
showing that very title, else any window of that app, found among the compositor's toplevels and
activated; with no window, the player is asked to raise itself. A browser playing in a tab that is
not the front one leads to the browser, not to the tab: MPRIS does not say which tab.

It is Geist and Material Symbols like the rest, on the theme's tokens. Its wave asks for cava
itself (`Audio.waveOpen`, or `wavePanel` in the window), so it keeps moving while a notification
holds the capsule above it.

**Symmetry of the window, by pixel, on 12/11/2026** in the harness, about the logo's center
(x 1280): the capsule 208 px each side, the panel 180, the seek bar and the volume 164, the three
keys 58, the logo's ink 1261 to 1298.
The panel's width is even so its middle is a whole pixel.

## How it moves

The island is the one place in the shell that moves on a spring and overshoots
([motion.md](motion.md#the-island)); the owner asked for the feel of motion.dev there, on
12/11/2026.

| Part                                         | Motion                                                                             |
| -------------------------------------------- | ---------------------------------------------------------------------------------- |
| The capsule opening or changing size         | a spring (`Theme.islandSpring` 5.0, `islandDamping` 0.37)                          |
| The capsule closing                          | an ease-out over `motionHover`, no spring: faster out than in                      |
| A NEW event's content                        | three beats 40 ms apart, out from the logo: the icon or cover, the name, the value |
| The same event's text changing (a new track) | the text fades through (`widgets/SwapText.qml`)                                    |
| A level's bar and its number                 | `motionFast`, no spring and no fade: it answers a key                              |
| The wave beside the cover                    | a step every 80 ms while media shows ([the wave](#the-wave)); not an animation     |

**Measured on 12/11/2026** from a trace of the capsule's reach, frame by frame, in the harness: with
spring 5.0 and damping 0.37 it passes its size by 3.9% of the travel (5.6 px opening from the logo
to a 176 px reach, 2.3 px between two sizes) and is within half a pixel of rest after 320 to 353 ms.
Four other pairs were traced on the way: damping 0.36 at spring 4.0 gave 1.9%, 0.33 gave 4.3%, 0.30
gave 7.6%, and 0.26 gave 13.5%. The capsule never gets narrower than the logo's own slot, so an
overshoot on the way down cannot uncover the logo.

With `my.theme.motion = "off"` the capsule takes its size at once (12 changes of its reach for one
notification, where the spring made about 68 frames) and the beats and the fade do not run.

**What it costs**, same day, same harness: 20 brightness events in 10 s took 500 ms of the shell's
CPU against 490 ms on the tree without the spring, and with media resting in the capsule the idle
shell took 4.30% to 4.85% of a core against 4.00% to 5.45% with the island empty. Nothing in either
pair stands out of the spread.

## What it replaced

| Before                         | With the island up                                                                  |
| ------------------------------ | ----------------------------------------------------------------------------------- |
| The bottom OSD                 | its events go to the capsule; the window stays shut                                 |
| A toast for every notification | a plain one goes to the capsule; a critical one, or one with buttons, stays a toast |
| The media item on the bar      | what plays rests in the capsule; the controls are in the Control Center             |

A notification is never shown twice: `Notifs.qml` sends each one either to `popups` (the toasts) or
through `arrived` (the island). Do-not-disturb, the away screen's hold and an open NixOS Center
silence both the same way, and a critical one still pierces all three as a toast.

## Turning it off

`my.shell.island.enable = false` (`quickshell/flags.nix`): the OSD, the toasts and the bar's media
item come back exactly as they were, and the bar's sides return to the logo's slot.

## Checked, and not

**Run on 12/11/2026** in a second Quickshell on a copy of the tree inside a headless sway, on a
private D-Bus session:

- The state-machine tests pass (`nix build .#checks.x86_64-linux.quickshell-logic`).
- A notification showed in the capsule; a brightness event 1 s later took its place; 1.7 s after
  that the notification was back; and it was gone when its time ended.
- A critical notification drew a toast and no capsule. Three notifications sent together left the
  third in the capsule.
- With the flag off, the same notification drew a toast and the brightness drew the bottom OSD.
- Idle cost, three 20 s windows of `/proc/<pid>/stat` each: 7.65% to 8.85% of a core before, 6.65%
  to 8.65% after, on a machine busier than on the day before (4% to 5% then). No difference
  between the two trees stands out of that spread.

A first version left a notification in the capsule forever: the timer fired a hair before the
deadline, the tick changed nothing, and a timer that re-armed only on a state change never fired
again. It re-arms itself now, and the same run caught it.

The resting media was run the same day with a stand-in for `Media.qml` in the test copy, since the
private bus has no player: the cover, the artist and the title showed, a brightness event and then
a notification took their place, and the media was back after each. The 17 state-machine tests pass.

The icons a notification brings were run on 12/11/2026 the same way: one naming a theme icon, one
naming a file and one naming nothing, from apps with no entry, drew the icon, the file and the
neutral glyph, in the capsule and at rest beside the title.

The apps that wait were run on 12/11/2026 the same way: a notification from ZapFast showed with
ZapFast's icon; with three unseen from two apps the capsule rested on `3 new` and both icons; the
list under it, opened over IPC, showed the three, newest first. The 18 state-machine tests pass.

Not verified: the volume and the microphone (the harness shares the machine's real Pipewire, so
nothing was changed there), a VPN's progress and its error, a Bluetooth device connecting, a real
player pausing and changing track, the disk warning, the pointer freezing the capsule, and every
click on it or in what it opens. How the spring LOOKS was never seen by a
person: only its numbers were measured. Of the wave: how it looks moving, and what it costs live with a game open. Of the media panel: the seek by press and drag, the three keys,
the volume and the way to the window on a real player (the stand-in's do nothing, and nothing in
the harness may change a volume). Of the open island: the hover itself (no pointer can be held still in the harness, so the rest
that opens the summary and the leaving that shuts it were never seen), every click, the click
outside that shuts the Center (the grab is Hyprland's), the keys inside the Center in its new
window (the harness has nothing to type with), `my.theme.motion = "off"`, how the opening LOOKS,
whether Hyprland stacks the two windows as sway did, and a screenshot taken from the Center with
the new wait.
