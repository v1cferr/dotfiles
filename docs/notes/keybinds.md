# The Hyprland keybinds

`home/desktop/hypr/lua/keybinds.lua`. At parity with the Arch/Kingston setup, with the tools
adapted to the NixOS stack.

**The comments in that file are not only comments**: the cheatsheet (SUPER+H) is GENERATED from
them at runtime. The first line of a comment block becomes the GROUP, and the trailing comment on
a bind's line becomes its DESCRIPTION. See [`desktop-plumbing.md`](desktop-plumbing.md) for the
parser's rules. So keep the first line of every block a good label, and keep the trailing comments.

## The monitor data has a self-contained fallback

The `dofile` of `~/.config/theme/monitors.lua` is wrapped in a `pcall` with a literal fallback,
because if the file is missing (the first boot before a rebuild, or new data not generated yet) the
`dofile` BLOWS UP and aborts the config. Since "autostart" comes later in the load order, the
session would come up with no services at all.

Do NOT factor this into a global helper: Hyprland does not share globals between `dofile` calls.

## The "/" key over remote access

Moonlight does NOT send the ABNT2 "/ ?" key (bug #1789, an international key). SCROLL LOCK is
remapped to "/" and Shift+ScrollLock to "?", since it is an idle key and this TKL has no Menu.

It uses `send_shortcut`, a NATIVE Hyprland dispatcher that sends the keysym straight to the active
window, independent of the layout and with no external exec, unlike `wtype`, which did not inject
through the bind. The ABNT2 layout is untouched and it works locally too.

**`key = "code:97"` and NOT `"slash"`**, and this one took real digging: `send_shortcut`'s
`resolveKeycode` sweeps the keymap with `xkb_state_key_get_one_sym`, which respects the modifiers
HELD AT THAT MOMENT, so it only finds a keysym at the ACTIVE level. With Shift held (the "?" bind)
no keycode produces `slash`, they produce `question`, giving "send_shortcut: key not found", and
the "?" never came out. The `code:` prefix short-circuits BEFORE touching the xkb state, so it is
immune to modifiers.

97 = `<AB11>`, the ABNT2 "/ ?" key (evdev `KEY_RO` 89 plus 8), checked against
`xkbcli compile-keymap --layout br --variant abnt2`.

The same reasoning is why the cheatsheet is on SUPER+H and not SUPER+/.

## The scrolling layout's tape

`move` scrolls the VIEW without touching the focus; with `follow_mouse=1` passing the mouse over
the column that came in is enough for it to receive the keyboard. The arrows still hold, because
`follow_focus` (the default) already brings the focused column into view.

**There is NO guard, because ALL the workspaces are scrolling.** If any goes back to dwindle,
reintroducing the guard is MANDATORY: a bind is global, a layout message is not, and on dwindle
Hyprland answers "Unknown dwindle layoutmsg" emitting ONE NOTIFICATION PER EVENT, so with the
thumbwheel in a burst the screen becomes a wall of toasts.

And `pcall` does not help: `checkResult` emits the notification and returns `{ok=false}` without
raising a Lua error. The guard (the version in git, commit 7f74ae8) filtered by
`hl.get_active_workspace().id`, because the workspace object does NOT expose `layout`. Inside a
lambda the dispatch is `hl.dispatch(d)`, never `d()` ("dispatcher objects cannot be called
directly").

### The mouse on the tape

The MX Master's thumbwheel is SUPER plus the horizontal wheel. logiops does NOT divert the wheel
anymore (see [`mouse.md`](mouse.md)): it goes back to emitting native `REL_HWHEEL`, so horizontal
scrolling inside the apps works normally, and the tape only moves with SUPER held.

The `binds:scroll_event_delay` ceiling (300 ms, ~3 firings/s) stopped being a problem: it was fatal
for smooth PIXEL scrolling, but for a COLUMN jump 3/s is plenty, all the more with
`column_width=1.0`, where one column is already the whole screen.

The VERTICAL wheel moves along the tape too. It used to switch workspaces, which was never used,
since a workspace is always keyboard (SUPER+1-8 or TAB). With no SUPER the wheel behaves normally
in the apps. The direction was set BY HAND, by testing: scrolling DOWN advances toward the side you
use most.

### Reordering, resizing and the view modes

`swapcol` moves the WHOLE COLUMN, the stack along with it, and wraps at the ends. To move a single
window out of a stack, `expel` (SUPER+O) first.

SUPER+ALT+`,`/`.` cycles the width of ONLY the active column. The CTRL trio changes the WHOLE tape:

| Bind | Message | What it does |
| --- | --- | --- |
| SUPER+CTRL+G | `fit all` | SEE EVERYTHING: resizes and repositions every column so they all fit |
| SUPER+CTRL+`.` | `colresize all 1.0` | FOCUS: everything at 100%, one window per screen |
| SUPER+CTRL+`,` | `colresize all 0.5` | everything at 50%, two side by side, fixed |

`fit all` differs from `colresize all 0.5`, which forces 2-per-screen even with 5 windows open. And
careful: `colresize all N` on its own does NOT bring the view along, since shrinking 2 columns to
0.5 left both off screen, to the left. `fit all` does both things.

**`fit active` and NOT `fit_into_view`**: the wiki documents the second, but 0.55.4 answers "no
such layoutmsg for scrolling". Every layout message requires a FOCUSED window; with no focus they
return "no focused window" and do nothing.

## "Arrange side by side", in one click

SUPER+middle click. It exists because on scrolling EVERY way of moving a window sideways (dragging,
`window.swap`, `window.move`) STACKS it into the destination column. Checked on all three, and it
is hardcoded in `CScrollingAlgorithm`. There is no horizontal drop.

So instead of fighting the drag, the bind UNDOES and normalizes: `expel` takes the window out of
any stack, into a column of its own, and `fit all` shows the whole tape on the screen.

It needs a lambda plus `hl.dispatch` because a bind accepts only ONE dispatcher, and here there are
two in order.

The mouse RESIZE (SUPER+right drag) is what puts one window beside another with the mouse:
scrolling implements a real resize-drag (the left border keeps the right one still by adjusting the
camera; the right border keeps the left one fixed), and shrinking the column reveals its neighbor.
The DRAG does not do that.

## Brightness, and the parenthesis that stopped working

There are no brightness keys on this keyboard, and no backlight on this desktop, so "brightness" is
hyprsunset's gamma with Quickshell's own OSD. SHIFT+VolUp is brighter, SHIFT+VolDown is darker, and
SUPER+SHIFT+B resets to 100%.

The reset used to be SHIFT+`code:19`, the physical 0 key. Binding that CONSUMED the keystroke, and
on ABNT2 `)` is Shift+0, so there was no closing a parenthesis. SUPER+SHIFT+B steals no typing key
at all.

## Small things worth not rediscovering

- `locked = true` means the bind works with the screen locked; `repeating = true` means it repeats
  while held. Media play/pause/next/prev get `locked` only, since repeating makes no sense there.
- SUPER+P (`pseudo`) is a dwindle thing and a no-op on scrolling, but it answers ok and raises no
  toast, so it stays harmless.
- SUPER+L goes `loginctl` to logind to hypridle's `lock_cmd`, and never duplicates hyprlock. See
  [`lockscreen.md`](lockscreen.md).
- The screenshot submap's `1`/`2` are POSITIONAL: 1 is the LEFT screen (the TV), 2 is the RIGHT one
  (the main LG). See [`flameshot.md`](flameshot.md).
- SUPER+F9 toggles the hyprsunset SERVICE; the other three F9 binds are one-off IPC overrides that
  hold until the schedule's next profile takes over. See [`hyprsunset.md`](hyprsunset.md).
- Relative workspace navigation (SUPER+TAB) is KEYBOARD ONLY: the mouse wheel left here and went to
  the tape, since switching workspaces on scroll was never used and the tape is what makes you want
  to scroll with the mouse.
