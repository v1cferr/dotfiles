# The island: one thing at a time, around the logo

`modules/home/desktop/quickshell/Island.qml`, `island/IslandMath.qml` and `bar/IslandSlot.qml`. A
capsule that grows out from behind the NixOS logo on the main monitor's bar, says one thing, and
goes. At rest it is not there: the logo stands alone and nothing repaints.

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
| 7        | A new track                               | 4 s                  | `Media.qml`                                   |

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
- **A less urgent event waits**, in a queue of three: one per key, and past three the least urgent
  leaves.
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

## What it replaced

| Before                         | With the island up                                                                  |
| ------------------------------ | ----------------------------------------------------------------------------------- |
| The bottom OSD                 | its events go to the capsule; the window stays shut                                 |
| A toast for every notification | a plain one goes to the capsule; a critical one, or one with buttons, stays a toast |
| The media item on the bar      | a track change is announced in the capsule; the controls are in the Control Center  |

A notification is never shown twice: `Notifs.qml` sends each one either to `popups` (the toasts) or
through `arrived` (the island). Do-not-disturb, the away screen's hold and an open NixOS Center
silence both the same way, and a critical one still pierces all three as a toast.

## Turning it off

`my.shell.island.enable = false` (`quickshell/flags.nix`): the OSD, the toasts and the bar's media
item come back exactly as they were, and the bar's sides return to the logo's slot.

## Checked, and not

**Run on 12/11/2026** in a second Quickshell on a copy of the tree inside a headless sway, on a
private D-Bus session:

- The 13 state-machine tests pass (`nix build .#checks.x86_64-linux.quickshell-logic`).
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

Not verified: the volume and the microphone (the harness shares the machine's real Pipewire, so
nothing was changed there), a VPN's progress and its error, a Bluetooth device connecting, a track
change, the disk warning, the pointer freezing the capsule, and every click on it.
