# The fans: an Arc B580 that was supposed to be uncontrollable

[`modules/nixos/hardware/fan-control.nix`](../../../modules/nixos/hardware/fan-control.nix) carries
the whole thing, and [`pkgs/xe-fan-control/`](../../../pkgs/xe-fan-control/) holds the kernel patch it
applies. Like the RGB work in [`gpu-rgb.md`](gpu-rgb.md), it is temporary by design: the section at
the end says when it goes.

This page exists because the repo said, in two places, that the card's fan speed could not be
controlled. That was true in September 2026. It is not true now, and the measurement that settles
it was taken here, on this card, because nobody else had published one.

## Why there was no fan control, and why that was never the real answer

`xe`'s hwmon exposes `fan1_input`, so the speed was always READABLE. What was missing was any way
to write one: no `pwm1`, no `pwm1_enable`, nothing.

The explanation everybody repeats is the MEI late binding firmware, and it is a red herring. The
card does want a fan control blob, and linux-firmware ships exactly one:

```text
fan_control_8086_e20b_8086_1100.bin.zst   # 8086:1100 is Intel's OWN limited edition board
lb_fan_control_version                    # on this ASRock card (1849:6020): EMPTY
```

So the blob for this board does not exist and never arrives. That is real, and it is also beside
the point: the blob feeds the card's AUTOMATIC fan behaviour. Manual control does not go through
it at all.

## What the manual path actually is

Intel has a patch series in review, **168027** (`drm/xe/hwmon`, Karthik Poosa), which adds `pwm1`,
`pwm1_enable` and `pwm1_auto_point[1-10]_{temp,pwm}` and programs them over the **PCODE mailbox**,
not over firmware. Two commands do all of it: `FSC_WRITE_FAN_TABLE` writes one point as
`temp | speed << 8`, and `FSC_WRITE_NUM_FAN_CONTROL_POINTS` commits the table by declaring how many
points it has. Committing ZERO points is how the card is handed back to its own stock curve.

`pwm1_enable` is the switch, and its three values are not the usual hwmon ones:

| Value | What the driver does |
| --- | --- |
| `0` | writes 100 into every point of the table: full speed |
| `1` | activates the user table, seeded from the stock points if it was never programmed |
| `2` | commits zero points: back to the card's own stock curve |

A write to `pwm1` is REFUSED unless the mode is already `1`. The duty is also not stored as you
wrote it: the driver converts it with `pwm = (pwm * 100) / U8_MAX`, flattens every point of the
table to that one value, and commits. Writing `200` therefore reads back as `199`, which is the
round trip through percent and not a bug.

## The question this card answered

The series was confirmed only on an **Arc Pro B60** (`8086:e211`, BMG G31). This machine has a
consumer **B580** (`8086:e20b`, BMG G21), and no public test of the consumer silicon existed. The
open question was narrow: does the consumer part's PCODE accept `FAN_SPEED_CONTROL` at all?

It does, and reading proved it before any write did. With the patch in, the driver pulled the
card's real stock table straight off the hardware:

```text
point  1   10 C -> 26      point  6   80 C -> 153
point  2   50 C -> 26      point  7   85 C -> 179
point  3   55 C -> 51      point  8   90 C -> 204
point  4   70 C -> 77      point  9   95 C -> 230
point  5   75 C -> 102     point 10  100 C -> 255
```

Then the write, on 14/10/2026, from a fan that had been sitting at a measured **0 RPM** for eight
straight seconds:

```text
pwm1_enable = 0      86 -> 675 -> 895 -> 985 RPM ...
after 60s            3926 RPM peak, holding around 3850
package temp         35 C -> 31 C          vram 38 C -> 34 C
```

The temperature falling is the part that does not depend on trusting the tachometer. The card
obeys across the full range, from a stopped fan to 3926 RPM.

## Two things that will mislead you later

**`fan1_max` is a lie, and harmlessly so.** The card declares 3600 RPM and the fan reached 3926,
which is 109% of the declared maximum. Anything that computes a percentage from `fan1_max` will go
over 100.

**Give the fan time before concluding anything.** A 20 second run from a dead stop reached only
about 1100 RPM and read as a failure. The same command held for 60 seconds reached 3926. The first
reading of a fan that was already coasting is not a baseline either, which is how an earlier test
here compared 0 against 1313 and declared success for the wrong reason.

## The board has two more, and nothing was reading them

The GPU was never the whole story. This board carries a **Nuvoton NCT6798D** at `0x2e`, and the
kernel has had the driver all along. It just never loads it, so `sensors` showed no motherboard fan
at all. One `boot.kernelModules` entry later it binds, with no ACPI resource conflict, and seven
tachometers plus six PWM channels appear.

What is actually connected, measured on 14/10/2026 by driving each channel to 100%:

| Channel | Low duty | Full duty | Verdict |
| --- | --- | --- | --- |
| `xe` `pwm1` (GPU) | 0 RPM | 3926 RPM | controllable |
| `nct6798` `pwm1` | ~290 RPM | ~1070 RPM | controllable, the CPU's |
| `nct6798` `pwm2` | ~563 RPM | ~1909 RPM | controllable, a chassis header |
| `nct6798` `pwm4`, `pwm5`, `pwm6`, `pwm7` | nothing responded | | empty |
| `nct6798` `fan3` | no PWM channel at all | | empty |

`pwm1` is the CPU's because of how it behaves rather than how it is numbered: under a full load on
all twelve threads it went from 285 to 930 RPM within five seconds of the load starting, while
`pwm2` drifted up 22% over a minute. The empty channels were each driven to full duty and listened
to, which is the only way to catch a three pin fan that spins with no tachometer wire to report it.

**`nct6798` `pwm1` has a broken tachometer.** It reported 29347 RPM and 28125 RPM at a fixed duty,
which is not noise in a reading script, it is impossible. Control responds correctly; the reading
is what lies. Expect a nonsense CPU fan figure in any panel that trusts it.

## Why CoolerControl and not LACT

LACT is the GPU tool and would have covered the Arc alone. Once the board turned out to have two
controllable headers, one interface for three fans beat two interfaces for three fans.
CoolerControl speaks plain hwmon, so it picks up the GPU's new `pwm1` and the board's channels
without knowing anything special about either.

The curve itself is NOT declared in the module. It is app state and belongs to CoolerControl's own
config, the same reasoning that keeps `services.lact.settings` empty in setups that use LACT: a
config written from the closure becomes a read only symlink and the GUI quietly loses the ability
to save.

## When this leaves

The patch costs a LOCAL KERNEL BUILD on every bump, with no binary cache, about an hour on this
machine. It is worth that only until the series lands.

Delete [`pkgs/xe-fan-control/`](../../../pkgs/xe-fan-control/) and the `boot.kernelPatches` block in
the module when `pwm1` shows up under the GPU's hwmon WITHOUT the patch. That is the whole test:

```sh
ls /sys/bus/pci/devices/0000:03:00.0/hwmon/hwmon*/ | grep pwm
```
