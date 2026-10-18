# The NixOS Center: notifications and the session, behind the logo

`modules/home/desktop/quickshell/bar/NixosCenter.qml`, with the service in `Notifs.qml` and the
toasts in `notifications/`. Since 17/10/2026 the official NixOS logo at the center of the bar opens
ONE panel holding everything that used to be spread over three controls: the notification history,
do-not-disturb, and the session (lock, darken, log out, suspend, reboot, shut down). The bell pill,
the band's bell and the power menu are gone; their functions are all here.

## What is in it

| Part | Holds |
| --- | --- |
| Header | the title, a do-not-disturb toggle and a clear-all button, both as icons with a name |
| Body | the history, newest first, scrolling past what the screen leaves (560 px at most) |
| Footer | the six session actions, their commands exactly the old power menu's |

**Do-not-disturb is an icon, never the word.** A bell when off, a struck bell in peach and a lit
background when on. The icon's tooltip and its accessible name are the same sentence
(`widgets/IconButton.qml`), so a control shown only as a glyph still says what it does. The state
**persists across restarts of the shell**: two keys in `Quickshell.statePath("notifs.json")`, read
synchronously at startup so a notification in the first instant cannot slip past a saved DND. It is
state, not configuration (rule 6), and it needed no daemon. Tested on 17/10/2026 through
`qs ipc call notif dnd`: the file went `false`, `true`, `false`.

**The three actions that end the session ask twice.** Log out, reboot and shut down turn red and
read `Confirm?` on the first click, and run on the second within 4 s; a reopened panel is never left
armed. Lock, darken and suspend run at once, since each is undone by coming back to the keyboard.

**The commands are the power menu's, unchanged**, with the same reasons: the lock starts
`hyprlock.service` before marking the `LockedHint` (`loginctl lock-session` alone only emits the
signal), darkening is gamma 0 through hyprsunset and never dpms, logging out is `loginctl
terminate-user` because LightDM starts a bare Hyprland. The history of each is in
[bar.md](bar.md#the-power-menu) and [lockscreen.md](lockscreen.md).

## How it opens and closes

It is a `BarPanel` keyed `center` in the bar's coordinator
([bar.md](bar.md#contextual-expansion-one-panel-at-a-time-17102026)), so it follows the same rules as
every bar panel, with one difference: it opens on a CLICK only, never on hover.

- **Where:** centered under the logo of the bar that was clicked, 520 px wide or the screen's width
  less the windows' outer gap on each side, 8 px under the bar. Measured on 17/10/2026: x 1020 with
  520 px on the 2560 px panel, so its center is 1280, the logo's.
- **One at a time:** opening it closes any other panel, the VPN menu and the media panel (over the
  media panel's IPC, since that one lives outside the coordinator). Clicking the logo of the OTHER
  monitor moves it there; the logical instance is one.
- **Closing:** the logo again, a click outside (a Hyprland focus grab whose whitelist holds the bar,
  so a click on another pill switches panels), or Escape. There is no timeout: the old center closed
  itself after 5 s, which is the wrong behavior for a panel you read and act in.
- **Keyboard:** it takes the keyboard only while open (`OnDemand`), which is what lets Escape reach
  it; Hyprland gives focus back when it closes. Tested with `wtype -k Escape`.
- **A screen that leaves takes it along:** the bars register by screen name, and a bar destroyed by a
  hotplug closes the panel it was holding, so no invisible window is left with the keyboard.
- **From the keyboard:** `qs ipc call notif toggle` opens it on the main monitor's logo.

## The unseen dot

A 6 px dot beside the logo, at a FIXED spot to the right of the SVG (never over it, never moving
it), shown only while a notification arrived with the Center closed and has not been seen. Red when
one of those is critical, the accent otherwise. Opening the Center marks them seen; a notification
that is only in the history never lights it, and neither does one carried over a hot reload.

## The toasts

`notifications/Notifications.qml`: top right of the main monitor (whichever screen is left when it
is unplugged), 8 px under the bar and on the windows' 12 px outer gap, 380 px wide, 8 px apart.

- **Three at most.** A fourth pushes the oldest off the screen, never out of the history.
- **None while the Center is open**, and opening it clears the ones on screen: the list already shows
  them. Do-not-disturb holds them too. A CRITICAL notification goes through both, as before.
- **Stable cards.** The toast list is a `ScriptModel`, which diffs the array: an arrival creates ONE
  card and the others keep theirs, with their dismiss timers. The old `Repeater` over a reassigned
  array rebuilt every card on each arrival, which restarted every timer (the oddity motion.md
  recorded) and needed a `fresh` flag to tell the newcomer apart. Both are gone.

Tested on 17/10/2026 with `notify-send`: two sent with the Center closed became two toasts and lit
the dot; three more left exactly three toasts (Test 3 to 5); opening the Center listed all five,
newest first, and cleared the dot. The test notifications were closed by id over D-Bus afterwards.

## The service, and what it costs

Quickshell stays the `org.freedesktop.Notifications` server (`Quickshell.Services.Notifications`):
history, actions, icons, images, urgency and DND were all already there, and no other daemon offered
something it lacks. What changed is around it:

- **The history has a cap**, `historyLimit` (100): past it the oldest go, but a CRITICAL or
  RESIDENT notification stays until it is dealt with.
- **The list is virtual.** A `ListView` over a reversed `ScriptModel` instantiates only the cards in
  view, and an arrival adds one delegate instead of rebuilding the list.
- **The icon fallback that could never work was removed.** For a name the current theme lacks, each
  card ran `find` over `/usr/share/icons/breeze*`; NixOS has no `/usr/share`, and no breeze theme is
  installed here, so every such card spawned a process to find nothing. The card now falls back to
  the bell directly (rule 16).
- **Sender data is untrusted.** Icon names, paths, image URLs and bodies come from whoever sent the
  notification; nothing here runs them or passes them to a shell, and the action buttons only call
  the notification's own `invoke()`.
