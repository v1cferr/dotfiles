# The backlight, over DDC/CI

`home/desktop/backlight.nix`. Both panels are held at ONE declared brightness and ONE white point,
set through DDC/CI instead of through the OSD's buttons.

## What made this possible, and what it explains

The August attempt at a real backlight curve was reverted because the OTHER screen of the time, a
TV on HDMI, does not speak DDC/CI at all. That screen left the desk in 09/2026, and both panels
that replaced the pair answer:

```text
Display 1  card0-DP-1  AUS:XG27ACS:TCLMTF117031
Display 2  card0-DP-2  GSM:LG ULTRAGEAR:307AZQV4Q196
```

Reading them the first time also settled an older complaint. The blue light filter looked like it
was skipping the LG, and the CTM was reaching it the whole time (`drm_info` proved the matrix was
on both CRTCs). The panels were simply starting from different places:

| | brightness | white point |
| --- | --- | --- |
| ASUS XG27ACS | 45 | 6500 K |
| LG UltraGear | 100 | **10000 K** |

10000 K is not even in the LG's own capabilities string, which lists 5000/6500/7500/8200 plus sRGB.
It is an OSD picture mode reporting a value outside the MCCS set. A warm matrix applied on top of a
10000 K panel at full brightness does not look like the same matrix applied on a 6500 K panel at
45%, which is why the filter read as broken on one screen.

## Why it needs no root

The `/dev/i2c-*` nodes are `root:root 0660`, and the session still reads and writes them, because
logind puts an ACL for the seat's user on them. That is the same mechanism `/dev/uinput` uses for
Sunshine. No `i2c` group, no udev rule of our own, no sudo.

## The retry is not defensive programming, it is a known race

The ACL appears when the session takes the seat. A unit that starts before that sees NO display at
all, and `ddcutil detect` returns empty rather than failing, so the run would be a silent no-op.
The script retries up to ten times, two seconds apart, and gives up quietly: the same shape of
boot race the mouse's DPI had, and the same answer.

## The display number is derived, never written down

`ddcutil --display N` counts its OWN enumeration, which nothing guarantees across a replug. The
script runs `detect` once per attempt, maps `DRM connector` to that number, and looks the connector
up from `my.monitors` (rule 11). One `detect` per attempt and not per monitor: it costs about 1.5 s
by itself.

## The cost, measured

A full run is about 2.9 s: one `detect` plus two `setvcp` calls per panel at roughly 650 ms each.
That is fine for a login and for an occasional `backlight-sync 30` by hand, and it is exactly why
the instant control (SHIFT+Vol, hyprsunset's gamma) stays where it is. A key held down cannot wait
650 ms per step.

## The number is the knob, and the same number is not the same light

45 on both is where they started, not a calibration: the ASUS is 350 nits typical and the LG 300,
so matching the digit is not matching the photons. `level` in the module is what to turn when they
stop matching by eye.
