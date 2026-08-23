# The Razer DeathAdder V2, its DPI OSD, and why there is no driver

`system/hardware/razer.nix`, `pkgs/razer-dpi.nix`, `home/services/razer-dpi.nix`, plus the `dpi`
mode in `home/desktop/quickshell/osd/Osd.qml`.

The goal was the thing Synapse does on Windows: press the DPI button under the scroll wheel and
see the new value on screen. The result does exactly that, with **no kernel module anywhere**.

## openrazer is OUT, and it is not a configuration problem

`hardware.openrazer.enable` exists in nixpkgs 26.05 and the module is fine. The DRIVER does not
build. Measured on 23/08/2026 against this machine's kernel (`linuxPackages_latest`, 7.2):

```text
razermouse_driver.c:1464:5: error: implicit declaration of function 'strncpy'
razerkbd_driver.c:2024:9: error: implicit declaration of function 'strncpy'
razeraccessory_driver.c:1102:9: error: implicit declaration of function 'strncpy'
```

The trap is that this reads like a missing `#include <linux/string.h>`, and it is NOT. **Kernel
7.x removed `strncpy` outright.** In `include/linux/string.h` on 7.2 the name survives only inside
comments, of the form "This is a replacement for strncpy() uses". Adding the include fixes
nothing, which I confirmed by building it with the include added: same three errors. The real fix
is rewriting every call site onto `strscpy` / `memtostr_pad`, which means owning a patch to an
out-of-tree kernel module.

Upstream has not even filed an issue for it. openrazer #2808 is a DIFFERENT kernel 7.x break (the
arity of `hid_report_raw_event`), and 3.12.3 already handles that one with a `LINUX_VERSION_CODE`
guard that covers 7.2. Versions 3.12.3, 3.12.4 and `master` all still lack the strncpy fix.

So the choice was: carry a kernel-module patch that upstream has not acknowledged and revalidate
it on every kernel bump, or stay in userspace. Userspace won, on 23/08/2026.

## The alternatives that do NOT work either

- **libratbag / Piper**: zero Razer support. Its `data/devices/` holds 125 files, covering asus,
  logitech, steelseries, roccat, glorious, sinowealth and others, and **not one** razer. The
  request for it is libratbag#103, still open.
- **razerctl** (userspace hidraw, the right idea): supports 6 models, and the DeathAdder V2 is not
  among them. Adding it would mean patching someone else's device table anyway.

## How razer-dpi talks to the mouse

It speaks the same HID protocol openrazer's driver speaks, from userspace, over `hidraw`. A Razer
report is 90 bytes and goes through `HIDIOCSFEATURE` / `HIDIOCGFEATURE` with a leading report
number byte, so the ioctl length is 91.

| Field | Offset | Value used here |
| --- | --- | --- |
| `transaction_id` | 1 | `0x3f`, which is what openrazer uses for THIS model |
| `data_size` | 5 | `0x07` |
| `command_class` | 6 | `0x04` (misc) |
| `command_id` | 7 | `0x85` (`get_dpi_xy`) |
| `arguments[0]` | 8 | `0x00` = NOSTORE |
| `crc` | 88 | a plain xor of bytes 2 through 87 |

The answer carries `status` at byte 0 (`0x02` means success) and the DPI big-endian inside
`arguments`: x at `[1][2]`, y at `[3][4]`.

**NOSTORE is the whole point.** It asks for the LIVE value rather than the one saved in the
profile, and openrazer's `razer_attr_read_dpi` confirms this model is on the query path, not on
the cached path that the ancient DeathAdder 3.5G and Orochi 2011 use. Reading DPI therefore costs
a round trip to the mouse and always reflects the onboard stage that is active right now.

**The interface has to be PROBED.** The mouse exposes four `hidraw` nodes and only one is the
control interface. On this machine it is `/dev/hidraw2`, but that number is not stable, so
`razer-dpi` tries each node and keeps the first that answers a DPI query with status `0x02`.

## Why it POLLS, and what that costs

The DPI button is handled entirely inside the mouse. It cycles the stages held in ONBOARD memory
and announces nothing to the host, so there is no event to subscribe to and no evdev key to bind.
Polling is not laziness here, it is the only channel.

That the host can see the change at all was the question the whole design hung on, so it was
measured before anything was written. Pressing the button through the stages produced:

```text
DPI CHANGED: 1600x1600 -> 2400x2400
DPI CHANGED: 2400x2400 -> 1600x1600
DPI CHANGED: 1600x1600 -> 2400x2400
DPI CHANGED: 2400x2400 -> 3200x3200
DPI CHANGED: 3200x3200 -> 2400x2400
```

The default interval is 250 ms (`--interval`). One poll is one feature report on the CONTROL pipe,
which is not the interrupt endpoint carrying movement, so it does not sit in the path of the
1000 Hz reports. Four of those per second is the price of the OSD.

The value read at startup is a BASELINE and never fires an OSD, because nobody asked for a toast
at login. With no mouse present the watcher idles on a 5 s rescan instead of exiting, so unplug
and replug needs no restart.

## `dpi_stages` is NOT available for this model

openrazer's driver only creates the `dpi_stages` file for some mice, and the plain DeathAdder V2
is not one of them (the V2 Pro, V2 Mini and V2 Lite are). The stage TABLE therefore lives on the
mouse, written by Synapse on the Windows side, and Linux can read and set the current DPI but not
reprogram the stages. That is also why the OSD shows the number alone with no bar: there is no
range to draw a fraction against.

## Access: uaccess, not a group

`/dev/hidraw*` is `root:root 0600` by default, so the udev rule tags the device with `uaccess`.
That hands the ACL to whoever is PHYSICALLY logged in on the seat, which is tighter than the
plugdev-style group openrazer wants, and it leaves no group membership to maintain. The rule
matches the four nodes by `idVendor`/`idProduct`, since udev cannot tell which one is the control
interface.

### The trap: `services.udev.extraRules` is TOO LATE for uaccess

The first version used `services.udev.extraRules`, and the ACL never appeared. The tag was applied
and the permissions were untouched, which is a confusing pair of symptoms:

```text
E: CURRENT_TAGS=:seat:uaccess:      <- the tag IS there
/dev/hidraw2 root:root 600          <- and no ACL was granted
```

`TAG+="uaccess"` does nothing by itself. What grants the ACL is systemd's `73-seat-late.rules`,
which matches `TAG=="uaccess"` and appends `RUN{builtin}+="uaccess"`. Rules run in FILENAME order,
and `services.udev.extraRules` writes into `99-local.rules`, so by the time the tag exists rule 73
has already run and decided. The tag is set, nothing reads it.

So the rule ships through `services.udev.packages` as `60-razer.rules` instead, which is the only
reason that option is used here rather than the shorter `extraRules`. Any `uaccess` rule in this
repo has to be numbered below 73 for the same reason.

## The OSD path

`razer-dpi watch` pushes `qs ipc call osd dpi <value>`, the same IPC door the brightness keys
already use, so the DPI toast is the same widget as volume and brightness rather than a second
notification system. The push is best effort: if Quickshell is not up, the watcher logs and
carries on, because the OSD is a nicety and not a reason to take the watcher down.

## The history entry that said this was obsolete

`docs/history/2026/08-august.md` closed a DeathAdder item as "obsolete, not done", on the grounds
that the mouse on this machine is an MX Master 3S and there was no Razer in the tree. The first
half was wrong: both mice are on this machine, the Razer is `1532:0084` and it was plugged in the
whole time. History is append-only, so the entry stays as written and this page is the correction.

The MX Master 3S is unaffected and keeps its own path through logiops: `hardware/mouse.md`.
