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

| Priority | Event                                               | Stays                | Comes from                                    |
| -------- | --------------------------------------------------- | -------------------- | --------------------------------------------- |
| 1        | The root filesystem about to fill                   | until it is answered | the bar's `df` (95% used or under 5 GiB free) |
| 3        | Volume, mute, microphone, brightness, DPI           | 1.5 s                | `osd/Osd.qml`, which keeps its anti-flash arm |
| 4        | A VPN's result; a task's (15 s when it failed)      | 4 s; 6 s             | the bar's VPN phases; `island task` over IPC  |
| 5        | A notification (a critical one stays)               | 5 s                  | `Notifs.qml`                                  |
| 6        | A Bluetooth device connected or gone                | 3 s                  | `Quickshell.Bluetooth`                        |
| 8        | Media playing: the cover, artist, title             | while it plays       | `Media.qml`                                   |
| 8.5      | The background: a VPN connecting, a task, a capture | while it lasts       | the same sources, and `Privacy.qml`           |
| 9        | Apps with notifications not seen yet                | until they are seen  | `Notifs.qml`                                  |

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
- **The background stands aside** (22/11/2026). A VPN connecting, a task running and a capture have
  no end and are not what the user is looking at: they rank under the media and over the apps that
  wait. Alone, one holds the capsule; while something plays, the music keeps it and they are icons
  at its far end, two at most, the more urgent kind first (`IslandMath.asides`). Until then a VPN
  connecting took the capsule from the music for as long as it tried. The RESULT is a moment at
  its kind's own priority, so it still interrupts, and what arrives replaces what waited under
  the same key wherever it waited.
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

A hover on the capsule OPENS the island into the NixOS Center, and a click pins it
([open](#open)). On a level or a VPN the click opens the Center on that page instead, and the disk
warning is dismissed by its click.

It exists only on the main monitor's full bar. With no screen wide enough for it (`Island.live`),
the OSD and the toasts do what they always did, so no event is ever sent to a capsule nobody sees.

**Under a fullscreen window** nobody sees it either (22/11/2026): the bar's layer is below one, and
until then a volume key or a plain notification in a game went to a capsule under the game.
`Island.covered` is the main monitor's active workspace holding a fullscreen window (the
workspace says so for a maximized one too, which covers nothing, so the window itself settles
it); `live` is false while it holds, and the OSD and the toasts rise to the overlay layer for
that time, since they sat under the game as well.

**On what plays, the pointer acts without opening** (22/11/2026): the wheel over the capsule is
the volume of what plays, 5% a notch (the player's own stream when it is known, else the
output's), and the middle button pauses it. The capsule says the level itself while the wheel
turns, since the pointer on it holds what the island shows. A click on a NOTIFICATION goes where
its card's arrow does: its default action, else its app's window (`Windows.find`), else the
Center as before. Each of them keeps the island shut until the pointer has been away
(`Island.hush`), or the Center would open under the wheel 200 ms later.

## The apps that wait

A notification shows with the icon of the app it came from, in the place of the bell: whose it is
reads before its words do. And while notifications wait to be seen, the apps they came from rest
in the capsule, up to three icons and a `+N` (12/11/2026, asked for with WhatsApp's messages as
the example):

- With nothing else to show, the capsule holds `3 new` left of the logo and the icons right of it.
- While media plays, the icons sit at the far end, after the title. Unseen apps are the least
  urgent thing of all (priority 9, no end), so they never hide what plays.
- Opening the island shows them in the Center's history and marks them seen, by a hover as by a
  click ([open](#open)). A notification that is dismissed or expires leaves the list by itself.

`Notifs.qml` owns the list (`unseenList`, and `unseenApps`, one entry per app, newest first); the
count on the logo's dot is the same number.

**Whose icon.** The app's `.desktop` entry first (`widgets/AppIcon.qml`). An app no entry answers
for wears what its notification brought (`Notifs.appIconOf`): a theme icon's name, a file's path,
or image data, in that order, and never a chat message's picture, which is a contact and not the
app. The first version looked at the entry alone, and on 12/11/2026 Sunshine and Zen rested in the
capsule as the neutral glyph while the list right under it drew their icons: the card read the
notification, the capsule did not. Both read one rule now.

## Capture

`Privacy.qml`, 22/11/2026. A phone and a laptop say when the microphone or the screen is in use;
here it showed nowhere. Each is a background state in the warning color, there for as long as it
lasts and never on a clock:

| What           | How it is known                                             | The capsule, alone             |
| -------------- | ----------------------------------------------------------- | ------------------------------ |
| The microphone | a Pipewire stream that records, and not from an output      | the app, `Microphone in use`   |
| The screen     | the compositor's `screencast` event                         | `The screen`, `Being captured` |
| A stream out   | a Pipewire stream recording an OUTPUT, from an app named so | Sunshine, `Streaming`          |

Not somebody listening, and left out: the shell's own wave (cava records the output), a mixer's
level meters, and a filter's own links. A stream that exists counts, running or not: an app that
keeps its microphone stream open while muted shows for all that time.

## A task in a terminal

`qs ipc call island task <id> <name> start|ok|fail <seconds>` (22/11/2026). Running, it is a
background state with its seconds counting, on a 1 s timer that runs only while the capsule shows
it. Ended, it is a moment: `Done · 3 min 12 s` for 6 s, or `Failed · 1 min 2 s` for 15 s in the
alarm's color, and a click dismisses either. The CALLER counts the seconds and hands them over,
so a shell the task itself restarted still says how long it took.

`rebuild` is the first to call it (`modules/home/shell/zsh.nix`): before `nh`, and after it with
the result. With no shell to tell, over SSH, the call fails quietly and the rebuild is the same.
It says nothing of the phase: reading `nh`'s output to tell a build from a switch would take its
terminal away from it.

## The card

Since 22/11/2026 a notification with more than a title brings the island down as a CARD under the
logo (asked for as "the notification and its content in the NixOS Center while it is not open":
a browser's finished download still opened a toast in the top right corner, since one with
buttons, or a critical one, never went to the island). The pattern is the iPhone's banner out of
the Dynamic Island.

- **Which:** one with a body, buttons of its own or the critical urgency (`Notifs.hasContent`). One
  with a title alone stays in the capsule, as before.
- **Where:** the same window and shape as the Center (`bar/IslandDrop.qml`), at a third size: the
  capsule's own width at its widest (416 px) and the card's height, on the island's spring. The
  logo stays on its pixel. The card is `notifications/NotifCard.qml` with `inIsland`: compact, and
  on the island's glass instead of its own.
- **How long:** 5 s, frozen while the pointer is on it; a critical one has no end and stays until
  it is answered. A hover on the card holds it and never opens the Center; the logo's click pins
  the Center, and the card grows into it without shutting first.
- **Its clicks:** the card goes where it leads (its default action, else its app's window, else
  the Center); a button is its own action; the close and the right button dismiss it. Dismissed,
  expired or closed by its app, it leaves the island at once (`Notifs.gone`).
- **The toasts** show only where the island cannot be seen: a fullscreen window over it, or the
  island off. They stand at the top of the screen's middle now, under the logo, and no longer in
  the right corner.

Run on 22/11/2026 in the harness with `notify-send` on its private bus: one with two buttons, one
with a body, one with a title alone (the capsule, no card) and a critical one (still out 6 s
later) each showed as said; pinning the Center grew the card into it; `notif clear` took the card
in; a hot reload crashed nothing; and with the island off the toast stood centered under the logo.
A hot reload forgets a critical card that was out (the notification stays in the history), as the
capsule always forgot what it showed. Not verified: a real download, any click on the card or its
buttons, the hover holding it, and a fullscreen window.

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

Open, the island IS the NixOS Center: one shape of glass in one window, grown out of the capsule
(21/11/2026). It was asked for in three steps. On 12/11/2026: "the whole capsule one hover zone, opening
downward", then "the whole NixOS Center as an island that adapts", which gave a summary on a
hover and the Center on a click, drawn as a head in the bar's window and a wider body under it.
On 21/11/2026 the owner sent a capture of that and asked for it cleaner, more fluid, opened by a hover
always, ONE thing with the island instead of two, and with stronger glass.

| State  | How it comes                                              | How it goes                          |
| ------ | --------------------------------------------------------- | ------------------------------------ |
| Rest   | always: the capsule, or the logo alone                    |                                      |
| Open   | the pointer resting 200 ms on the capsule or the logo     | 400 ms after the pointer left it     |
| Pinned | a click on the logo or the capsule, SUPER, `notif toggle` | the logo again, a click outside, Esc |

- **One window.** `bar/IslandDrop.qml` starts at the top of the screen and draws the whole shape:
  a rounded rectangle that is the capsule at one end of its motion (same place, same width, the
  capsule's own corners) and the Center at the other, 520 px wide. While any of it is out, the
  bar's capsule and logo step aside and this window draws the logo on the same pixels. Two
  windows had made it opaque (glass over two backdrops shows where they meet) and had left a
  shoulder where the widths differed; one window has neither.
- **The bar gets a hole.** While the island is out, the bar window's input mask leaves out the
  stretch it covers (`BarStrip.qml`), so the pointer reaches the island whichever of the two
  windows the compositor stacks on top.
- **Always mapped, empty while shut.** Zero tall and taking no pointer, so opening is the island's
  own motion from its first frame: no layer to map, no fade of the compositor's over it. It is
  shown one turn of the event loop after it is made, never at once: on 12/11/2026 the first hot
  reload after it went live crashed the shell in `QWindow::setScreen` (Quickshell 0.3.2 restarted
  itself, and the notification history in memory was lost). A stand-in window of ten lines,
  visible from its first instant, did the same on every reload in the harness.
- **A hover opens it, a click pins it.** The zone is the capsule from the screen's top edge to the
  bar's foot, and the logo, so it opens with nothing in the capsule too. Open by a hover it is the
  Center just the same (what it shows counts as seen) but never takes the keyboard; pinned is the
  bar's coordinator's `center` pin ([nixos-center.md](nixos-center.md#how-it-opens-and-closes)).
  Dismissed with the pointer still on it, it does not open again until the pointer has been away.
  A pinned panel is never taken down by a hover.
- **Glass.** `Theme.colSurfaceIsland`: 60% of the palette's bg, the most see-through surface of
  the shell, over the compositor's blur and the HyprGlass preset its layer `qs-island` gets
  (`hypr/lua`). HyprGlass takes a surface only from half opaque up, which is the floor.
  `my.shell.island.glass.enable = false` makes it opaque, and so does a shell whose generation has
  not written the flag yet: see-through over an unblurred desktop is not readable (the harness,
  which has no blur, showed exactly that over the standing monitor's band).
- **On the other monitor** its logo opens the Center there in the same shape, by a hover as by a
  click (the hover since 22/11/2026). The pointer resting on that logo calls the island over
  (`Island.aim`) while it is shut, and it goes back once shut with the pointer off the logo. It
  starts there from the logo's own slot: the capsule rests only on the main monitor.
- `Island.qml` owns the state (`open`, `full`, the three hovers, `where`, `headHalf`);
  `qs ipc call bar island open` and `close` stand in for a hover, `bar islandAim <screen>` for
  the logo it rests on, and `bar islandReach` says how far it reaches under its head, in px.

| Part           | Motion                                                                             |
| -------------- | ---------------------------------------------------------------------------------- |
| The width      | the island's spring, from the capsule's width to 520 px, never past the window     |
| The height     | the same spring, damped at 0.45 past 400 px of travel: the Center settles          |
| What it holds  | follows the glass: its opacity is how far the glass has come, with a 6 px slide    |
| Card to Center | a cross-fade on that same progress: the card out, the Center in, no frame bare     |
| Open, resized  | a page, the media card: a 180 ms ease with no overshoot; what enters fades with it |
| Shutting       | an ease-out over `motionHover`, the Center fading as the glass rises               |

**Recorded live on 22/11/2026, and fixed the same day.** The owner sent a recording of the island in
use (32 s at 180 fps): "not fluid and harmonious". Taken apart frame by frame, every fault had one
cause: the glass moved, and what it held changed at once or on a clock of its own. The Center came
down on bare glass for three frames (an 80 ms wait, then a fade of its own); a card turning into
the Center blinked out first; closing the Center put the card back into the still tall glass before
it shrank; and unfolding the media card or opening a page snapped the content while the spring
trailed, cutting the foot on the way out and leaving bare glass on the way in. Now what it holds
follows the glass (`IslandDrop.centerShown`, `cardShown`), opening the Center consumes the card
(its notification is right there in the history), and once settled a size change is a short ease.

Traced frame by frame in the harness (a `FrameAnimation` logging the glass and both opacities in
the test copy only, since a capture took 176 ms): from the card, the Center rose from 0 as the card
fell from 1, crossing at a third of the way, with no frame of both at 0; from the capsule the
Center was at 0.11 on the first frame the glass moved; shutting, it fell to 0 with the glass;
shutting after the card, the card did not come back; and a page 420 px shorter took the glass from
573 to 153 px in about 190 ms without passing it. Four hot reloads, with the card out and the
Center pinned, crashed nothing. Not seen: a page or the media card growing the open Center (no
command reaches them in the harness), and how all of it looks to the owner.

**A second recording, the same day.** Two faults were left. The open Center held still for about
260 ms each time it got SHORTER (the media card folding, a shorter page) and then jumped: the
island's window followed its content's height, and a layer surface that resizes waits on the
compositor's answer. On Hyprland that held the frame; sway, in the harness, never did, which is
why the first round did not see it. The window now grows at once with 260 px of headroom and
shrinks only while the island is shut (the room left over is transparent, and the blur ignores
it: `ignore_alpha`). And a page faded in from nothing, which read as a blink: it starts from 40%
now and slides 16 px in from its side (`widgets/FadeIn.qml`). Traced in the harness with a
command added to the test copy only: unfolding and folding the media card kept the window at
771 px throughout, the glass easing 458 to 687 px and back in about 190 ms each way.

**Measured on 21/11/2026** in the harness, every state driven over IPC:

- The spring: 744 px down, passed by 0.7 px, within half a pixel of rest after 368 to 386 ms, half
  way at 64 to 82 ms and nine tenths at 161 to 178; shutting took 78 to 112 ms over 8 frames.
- Symmetry about the logo: the open shape 260 px each side of x 1280, on the capsule's row and
  300 px down; the resting capsule 147; on the second monitor (center 540) 260 and 260.
- The logo: in its 20 px box, no pixel changed by more than 24 levels between the island shut and
  open (the glass behind it differs; an edge that moved would differ by far more).
- Hot reloads: two each with the island shut, open by a hover and pinned, and one from the tree
  that was live to this one: no crash.
- Idle cost, three 12 s windows on a quiet machine: 4.83% to 5.75% of a core with the island
  never opened, against 4.25% to 4.58% on the tree before. After one opening and shutting it was
  6.75% to 6.92%: the Center, once made, kept rebuilding its status columns at every 2 s tick of
  the bar's snapshot, shown or not (it did before this change too). The columns are modeled by
  count now; a game started before that could be measured again.

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

| Before                         | With the island up                                                    |
| ------------------------------ | --------------------------------------------------------------------- |
| The bottom OSD                 | its events go to the capsule; the window stays shut                   |
| A toast for every notification | the capsule, or the island's card when it has more than a title       |
| The media item on the bar      | what plays rests in the capsule; the controls are in the NixOS Center |

A notification is never shown twice: `Notifs.qml` sends each one either to `popups` (the toasts) or
through `arrived` (the island), and the toasts only where the island cannot be seen. Do-not-disturb
and an open NixOS Center silence both the same way, and a critical one still pierces both.

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
that opens it and the leaving that shuts it were never seen), every click, the click outside that
shuts it pinned (the grab is Hyprland's), its keys (the harness has nothing to type with), the
blur and HyprGlass on its layer and so how readable the glass is, what its always mapped layer
costs the GPU while shut, `my.theme.motion = "off"`, and how the opening LOOKS.

**Run on 22/11/2026** in the harness, every state over IPC: the 20 state-machine tests pass; a
task running stood aside of the stand-in player as an icon, and showed `Done · 3 min 12 s` and
then `Failed · 1 min 2 s` in the capsule; with `Privacy.micBy` forced to a name the microphone
stood aside of the music, and held the capsule alone with the task aside of it; the real
Pipewire of that hour (the shell's own cava recording the output) lit nothing; the island opened
on the second monitor after `islandAim` and on the main one again after shutting; and nine hot
reloads (shut, open on the second monitor, aimed, pinned, with a task) and one from the tree
that was live crashed nothing. That last one loaded `Island.qml` before `Privacy.qml` had been
copied and logged `Privacy is not defined` until the next reload: a merge needs its
`qs-restart`.

Not verified, all of it needing the live session: a fullscreen window (the harness is sway, with
no `Hyprland` to ask), the `screencast` event, a real microphone stream and whether a muted call
keeps it, the name Sunshine's stream carries, the wheel and the middle button (nothing in the
harness may change a volume, and it has no pointer), a notification's click, the hover on the
second monitor's logo, and `rebuild` calling in from a real switch.
