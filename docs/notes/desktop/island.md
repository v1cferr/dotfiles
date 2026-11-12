# The island: one thing at a time, around the logo

`modules/home/desktop/quickshell/Island.qml`, `island/IslandMath.qml` and `bar/IslandSlot.qml`. A
capsule that grows out from behind the NixOS logo on the main monitor's bar, says one thing, and
goes. With nothing to say it is not there: the logo stands alone. While media plays it rests open, still,
with the cover and the title.

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

A click leads to the surface that holds the rest: a notification to the NixOS Center, a track to
the media panel under the logo, a level or a VPN to the Control Center. The disk warning is
dismissed by its click.

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
- A hover that rests on the capsule opens the PEEK (`bar/NotifPeek.qml`): the four newest of them
  as the same cards the NixOS Center uses, by the bar's own hover rules (`Theme.hoverIntent`, and
  it closes when the pointer leaves both).
- Seeing them in the peek does not mark them seen. `Mark as seen` at its foot does, and so does
  opening the NixOS Center, by a click on the capsule or on the other row. A notification that is
  dismissed or expires leaves the list by itself.

`Notifs.qml` owns the list (`unseenList`, and `unseenApps`, one entry per app, newest first); the
count on the logo's dot is the same number.

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

The apps that wait were run on 12/11/2026 the same way: a notification from ZapFast showed with
ZapFast's icon; with three unseen from two apps the capsule rested on `3 new` and both icons; the
peek, opened over IPC, listed the three, newest first. The 18 state-machine tests pass.

Not verified: the volume and the microphone (the harness shares the machine's real Pipewire, so
nothing was changed there), a VPN's progress and its error, a Bluetooth device connecting, a real
player pausing and changing track, the disk warning, the pointer freezing the capsule, the hover
that opens the peek, and every click on it or in the peek. How the spring LOOKS was never seen by a person: only its numbers were measured.
