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
| Notifications | the history, newest first and grouped, scrolling on its own past 480 px (less on a short screen) |
| Hardware | CPU and GPU temperature, RAM, disk: four cards (v2.3) |
| Power | the Balanced/Gaming/Eco profile, what its last apply did, and five memory and GPU readings (18/10/2026) |
| Boot | Secure Boot, the loader and the integrity check, as `boot-trust` proved them (22/10/2026) |
| Screenshots | the two monitors by name (ASUS, LG), Both, and where the shot goes, always open (v2.3) |
| Session | the six session actions, their commands exactly the old power menu's |

The history scrolls by itself, so however long it grows, the three sections below it stay in reach.

**Do-not-disturb is an icon, never the word.** A bell when off, a struck bell in orange and a lit
background when on. The icon's tip reads `Do Not Disturb / Enabled / Click to disable`, its title
also the accessible name (`widgets/IconButton.qml` on `widgets/GlassTip.qml`, the shell's glass card,
since Qt's native tooltip drew a light box off the theme), so a control shown only as a glyph still
says what it does. The state
**persists across restarts of the shell**: two keys in `Quickshell.statePath("notifs.json")`, read
synchronously at startup so a notification in the first instant cannot slip past a saved DND. It is
state, not configuration (rule 6), and it needed no daemon. Tested on 17/10/2026 through
`qs ipc call notif dnd`: the file went `false`, `true`, `false`.

**The three actions that end the session ask first, in the card** (22/10/2026, replacing the
second click). Log out, reboot and shut down turn the Center's own card into the question
(`bar/PowerConfirm.qml`): Cancel is focused, Escape or closing the Center cancels, the arrows or Tab
move between the buttons, Enter confirms. Lock, darken and suspend run at once, since each is undone
by coming back to the keyboard. Details in [the confirmation](#the-confirmation-22102026).

**The commands are the power menu's, unchanged** (they live in `power/PowerMath.qml` now), with the same reasons: the lock starts
`lockscreen.service` before marking the `LockedHint` (`loginctl lock-session` alone only emits the
signal), darkening is gamma 0 through hyprsunset and never dpms, logging out is `loginctl
terminate-user` because LightDM starts a bare Hyprland. The history of each is in
[bar.md](bar.md#the-power-menu) and [lockscreen.md](lockscreen.md).

## The confirmation (22/10/2026)

`Power.qml` owns the six actions; the Center's footer and `qs ipc call power ask <key>` only request
them. The rules it keeps:

- **One command at a time.** The state machine is pure (`power/PowerMath.qml`, phases `idle`,
  `confirm`, `busy`, `handoff`, `error`) and `quickshell/tests/tst_power.qml` covers it: a double
  confirm never runs twice, a running command cannot be cancelled into a lie.
- **The exit code is read.** The old footer fired the command and closed the panel. Now a non-zero
  exit shows the command's last stderr line, so a poweroff held by a logind inhibitor or a suspend
  that failed says so, in the card, for any of the six.
- **No fake progress.** When reboot or shut down is accepted the card says `Restarting` or
  `Shutting down`, static, and the OS takes over. If nothing happened after 90 s (a delay
  inhibitor), it turns into an error instead of waiting forever.
- **In the card, not over the desktop.** The first version was a separate window, centered and
  dimmed on the main monitor. Seen live, the choice was the card itself: the question stays where
  the click was, and there is no second window, scrim or keyboard grab to keep in step with the
  Center's. Its keys are the panel's: Escape inside the question answers no and keeps the Center
  open; the panel's own Escape handler gets the keyboard back after (`BarPanel.takeKeys`).
- **Closing is a no.** A click outside or the logo closes the Center, and a closed Center cancels a
  pending question. Nothing confirms by going away.
- **It comes to you.** A question over IPC, or a failure of an action that closed the Center
  (suspend), fires `Power.attention`, and the Center opens itself on the main monitor through the
  same path as `qs ipc call notif toggle`.
- **Motion** is the Center's own: no new animation; the buttons' color uses `Theme.ms()`.

Tested on 22/10/2026 with the whole shell in a headless sway, `hyprctl` stubbed out and
`QS_POWER_DRYRUN` set (every command becomes `exit 0` or `exit 1`, and the test copy also replaced
the commands with `true`): the card turned into the question, Escape brought the sections back,
Right then Enter confirmed, a failure showed `Shut down failed (exit 1).` with Close focused and
Enter on it brought the sections back, a failed suspend opened the closed Center, and success
showed `Restarting`. Not yet seen on Hyprland, where the focus grab is the real one.

## Boot (22/10/2026)

Three cards read from `/run/boot-trust.json` when the panel opens (`bar/BootTrustSection.qml`, the
mapping in `data/BootTrustMath.qml`, tested by `tests/tst_boottrust.qml`). The file is written by a
read-only root oneshot ([boot](../boot-and-storage/boot.md#what-boot-trust-records)), so the shell
needs no privilege. Green needs evidence: Secure Boot on in USER mode, a loader that passes
`sbverify` against our db key, and an enrolled config proven for THIS boot. Anything short of that
is yellow, a failure is red, and no record is Unknown. Under GRUB the honest reading is `Partial`,
`initrd not verified`.

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
- **From the keyboard:** SUPER alone (22/10/2026), the Windows-key menu, runs `qs ipc call notif
  toggle`, which opens it on the main monitor's logo. The bind fires on RELEASE and only as a
  `click`, so SUPER plus a mouse drag does not open it ([keybinds](keybinds.md#super-alone-opens-the-nixos-center)).

## Driving it from the keyboard (22/10/2026)

Every control in the card carries a `widgets/KeyTarget.qml`: the header icons, each notification
card and group, the four hardware cards, the three power profiles, the screenshot targets and the
six session actions. One global bind opens the Center; inside it the keys are plain ones:

| Key | Does |
| --- | --- |
| Tab, Shift+Tab, the arrows | walk the controls in reading order; from the panel an arrow starts at the first (Down) or the last (Up) |
| Enter, Space | what a click does |
| Delete, Backspace | dismisses the focused notification (a group: all of it) |
| Escape | closes the Center from anywhere; inside a question it only answers no |

**The arrows are linear**, like Tab, not a 2D grid: rows here have 1 to 6 items and change shape
with the history, so "the item below" would be a guess, and a linear walk is predictable.
**The ring shows only for the keyboard**: a click focuses nothing, and every open hands the focus
back to the panel, so the Center never opens with a ring left from last time. Disabled controls
(clear with no history, a target whose monitor is off) are skipped. Not covered: a notification
scrolled out of the list's view is focused without scrolling to it.

Tested on 22/10/2026 with the whole shell in a headless sway: Down lit the do-not-disturb bell,
Up from the panel wrapped to Shut down, Enter asked, Escape answered no, Escape again closed it.
Enter on a power profile was NOT pressed there: it talks to the real power-profiles-daemon.

## Power (18/10/2026)

`bar/PowerSection.qml`, between the hardware and the screenshots. The profiles themselves, what
each one changes and why ppd owns them: [power](../hardware/power.md).

- **Three buttons, Balanced, Gaming, Eco.** A click sets `PowerProfiles.profile` through
  Quickshell's native binding (`Quickshell.Services.UPower`), so the shell asks power-profiles-
  daemon over D-Bus and polkit decides; the shell holds no privilege and runs no command. The
  active profile is the one ppd REPORTS, outlined in the accent. A switch ppd did not confirm
  within 3 s turns the status line red (`ppd did not switch`), so a refusal is never silent.
- **A hold says so**: while GameMode holds `performance`, a line reads `Held at Performance by
  GameMode, until it ends`, and the pick underneath stays the one ppd returns to.
- **The status line** is `power-profile-sync`'s last apply, from
  `$XDG_RUNTIME_DIR/power-profile.json`: SignalSift's profile and the Ollama outcome, red when
  either failed. It is read when the Center opens and 1.5 s after a profile change, never on a
  timer. Without the file the buttons are greyed and the line reads `power-profiles-daemon not
  running`, which is the state before the switch.
- **Five readings**, all from the bar's own 2 s snapshot (no read of their own): available RAM,
  zram's data and the RAM it really takes with the ratio (`/sys/block/zram*/mm_stat`), the NVMe
  swap in use (`/proc/swaps`, any device that is not zram), memory pressure (`full avg10`, yellow
  from 10%, red from 30%, the bar's own alert line), and the GPU BOARD watts from the `xe`
  sensor, captioned `xe sensor, not the wall`. CPU watts are absent on purpose: RAPL is root-only
  here, and a number the shell cannot read is not shown.

The history's height budget grew from 360 to 520 px of reserved space for the new section.

Checked on screen on 18/10/2026 with ppd running: Balanced outlined in the accent, the line
reading `SignalSift balanced · Ollama kept`, and the five cards at 5.4 GB available, 5.1 GB of zram
data in 1.4 GB, 3.0 GB on the NVMe, 0.0% pressure and 45 W on the GPU board with the desktop idle.
The zram card's caption elides its ratio at 520 px; the full text is in its accessible name.

## Screenshots (18/10/2026)

A `SCREENSHOTS` section between the hardware and the session, ALWAYS open since v2.3 (it was a folded
line): three targets, the two monitors by their `my.monitors` names (`ASUS`, `LG`; `Main` and
`Side` on a host that sets none) and Both, and, beside the title, where the shot goes, the clipboard by
default (as the keybinds do) or a PNG in `~/Pictures/Screenshots`, named
`<date>_<time>_<target>-<connector>.png` (`..._all.png` for the whole layout). A monitor that is not
connected greys its button out.

A click closes the Center and runs `shell-screenshot <target> <copy|save>` (`flameshot.nix`), which
reuses Flameshot and `my.monitors`: it waits for the Center's own layer, `qs-center`, to leave the
frame and for Hyprland's 100 ms layer fade, then shoots. The capture is Flameshot's, the same backend
as `sc1`, `sc2` and `scfull`, and Flameshot's own notification is the success feedback; a failure
(a monitor gone, Flameshot failing) is a notification too. No new daemon.

Tested on 18/10/2026: PNGs at native resolution, 2560x1440 (main), 1080x1920 (the LG, rotated) and
3640x1920 (the whole virtual layout); a copy left `image/png` 1080x1920 in the clipboard; and a shot
fired the instant the Center closed showed no trace of it, 909 ms from close to file. Shared images
are often scaled down by the app they are pasted into; the original file is the native one.

## Hardware

A row of four cards (v2.3): CPU and GPU temperature, RAM and disk use, each with what it is read from
(`coretemp`, `xe`, the bytes used, the space free). It READS the bar's own snapshot (the `/proc` and
hwmon read every 2 s, and `df` every 30 s): no read of its own. A sensor the machine does not publish
shows `n/a` with `no sensor`, never a number. Colors follow the states catalog
([theme.md](theme.md#states)): a temperature against ITS OWN ceiling (70% warning, 80% degraded, 90%
critical), RAM 90%+ warning, the disk with the same rule as the bar's chip. A card opens its detail
panel, still under the logo: the temperatures for CPU and GPU, CPU and memory for RAM and disk. That
is where the temperature went when it left the bar; the band stays the full view.

Measured on 18/10/2026: CPU 58°C from `coretemp`, GPU 50°C from `xe`, RAM 84%, disk 62% with
361.7 GB free.

## The history, grouped

The list is a VIEW over the server's notifications, never a replacement: grouping removes nothing.
Similar notifications fold into one card (`notifications/NotifGroup.qml`): the app, how many, the
summary, and a tally of what they said (`2 × Capture saved · 1 × Capture aborted`). A click expands it
into its members, each with its own time, text, actions and close; the ✕ on the group closes them all.

**Similar, conservatively:** the same app AND the same summary, each within 5 min of the previous one.
Never grouped: a critical notification, one with actions of its own, a chat message (category
`im.*`). So a run of screenshots folds, while messages keep their sender and their reply buttons.

**Stable delegates.** The model is a list of KEYS (`n:<id>`, or `g:<id>` keyed by the group's OLDEST
member, which a newcomer never changes); a `ScriptModel` diffs strings by value, so an arrival adds
one delegate and a growing group keeps its own, its content read live from a map.

**Times.** The server keeps none, so `Notifs` records each arrival (`arrivedAt`, pruned when one
leaves the history); a card shows `now`, `3 min`, `2 h`. One handed over by a hot reload gets the
reload's time, the closest the shell can know.

Tested on 18/10/2026: three `notify-send -a v23-test Screenshot` with two bodies became one group
reading `3 events` and `2 × Capture saved · 1 × Capture aborted`, while a kitty notification with an
action of its own stayed alone; the three were closed by id afterwards. Expanding a group was not
tried by hand.

## The cards

`notifications/NotifCard.qml`, CONTEXTUAL GLASS: no frame per urgency any more. Hierarchy comes from
type and spacing (the app and the time in small text, the summary bold, the body in `subtext`), the
Center's cards are a faint inset on its glass, and a CRITICAL notification alone gets a 3 px red strip
and a red summary. Normal and low read neutral: urgency is the only semantics freedesktop
guarantees, so a green "success" would be a guess.

## The unseen dot

A 6 px dot beside the logo, at a FIXED spot to the right of the SVG (never over it, never moving
it), shown only while a notification arrived with the Center closed and has not been seen. Red when
one of those is critical, the accent otherwise. Opening the Center marks them seen; a notification
that is only in the history never lights it, and neither does one carried over a hot reload.

## The toasts

`notifications/Notifications.qml`: top right of the main monitor (whichever screen is left when it
is unplugged), 8 px under the bar and on the windows' 12 px outer gap, 380 px wide, 8 px apart. A
toast is the COMPACT card: a 28 px icon, the summary on one line and the body on two, never taller.

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
