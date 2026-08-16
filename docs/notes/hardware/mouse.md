# The MX Master 3S, logiops, and the boot race

`system/hardware/mouse.nix`. A declarative configuration through logiops (the `logid` daemon),
which runs as a systemd service (root, so it reaches hidraw) and applies the config on hotplug.

It is connected over Bluetooth (logiops 0.3.x already speaks HID++ over BT). If one day it is not
detected over BT, plugging the Bolt receiver that comes in the box solves it with no change to the
file.

## The boot race, and why the fix is udev plus a delay

logid has a boot race AND it does not re-detect on reconnect: if the mouse connects AFTER logid
comes up (BT pairs with a delay at boot, or it reconnects after sleeping), the DPI stays at the
default 1000 instead of the configured value.

Restarting logid at the INSTANT of the connection does NOT work either: it fails with "5 tries",
because the BT HID++ has not answered yet.

So the fix is udev: when the MX Master (`046D:B034`) connects, it fires a oneshot that WAITS 5 s
for HID++ to wake up and ONLY THEN restarts logid.

## The thumb wheel stays NATIVE, on purpose

There is no `thumbwheel` block. Native means `REL_HWHEEL`, which is what makes horizontal
scrolling work INSIDE the apps: VS Code, a wide table in the browser, Dolphin. What scrolls the
Hyprland tape is SUPER plus the wheel, bound on `mouse_left`/`mouse_right` in
`home/desktop/hypr/lua/keybinds.lua`.

There used to be a `thumbwheel.divert = true` here synthesizing SUPER+CTRL+`,`/`.`. The reason was
escaping the 300 ms ceiling of `binds:scroll_event_delay`, which throttles a wheel bind to ~3
firings/s. It became unnecessary when the tape started moving COLUMN by column (with
`column_width=1.0`, 1 column = 1 screen): 3 screens/s is plenty, and the cost of the divert
(killing the apps' horizontal scroll) did not pay off.

If the divert is ever needed back: `interval` is ignored on the thumbwheel, since logiops fires on
every increment (PixlOne/logiops#310, open).

## The gestures, and why they only reuse existing binds

The gesture button (cid 195, `0xC3`, under the thumb rest) manages THE TAPE with the thumb, ever
since scrolling became global and a workspace stopped being where you stock windows.

| Gesture | Bind it synthesizes | What it does |
| --- | --- | --- |
| Left / Right | SUPER+SHIFT+`,` / `.` | MOVE the window along the tape (`swapcol l/r`) |
| Up | SUPER+CTRL+G | see everything (fit all) |
| Down | SUPER+CTRL+`.` | focus, 1 per screen (`colresize all 1.0`) |
| click, no movement | SUPER+Q | the app launcher |

Left/Right is the "put it beside with the mouse": dragging does not do that, it stacks, hardcoded.
Up/Down is the pair of view modes, on the thumb.

Every gesture synthesizes a bind that ALREADY EXISTS in `keybinds.lua`. No new action gets
invented just for the mouse, because the cheatsheet (SUPER+H) is generated from `keybinds.lua` and
would not see it. Switching workspaces stays on SUPER+1..8, SUPER+TAB and SUPER plus the vertical
wheel.

## The rest

`dpi = 2222` (native is 1000, the range is 200 to 8000; tune to taste). `smartshift` switches the
wheel between ratchet and free spin based on the spin's force, with `threshold = 15` (lower
releases more easily). `hiresscroll` is smooth pixel-by-pixel scrolling.
