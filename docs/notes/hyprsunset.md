# hyprsunset: the blue light curve

`home/desktop/hyprsunset.nix`. Docs: <https://wiki.hypr.land/Hypr-Ecosystem/hyprsunset/>

It acts through the compositor's CTM (`hyprland-ctm-control-v1`), so it does NOT show up in a
screenshot or a recording, which matters because Flameshot is used directly.

**A correction (08/08/2026)**: this used to say the choice was "instead of gammastep/wlsunset
because it is not a shader". The argument was crooked, since gammastep and wlsunset do NOT use a
shader either. What does is hyprshade, and it is against THAT one that the Hyprland wiki recommends
hyprsunset ("preferred to screen shaders as it will not be captured via recording/screenshots").
The real reason to prefer it over the other two is being native to Hyprland's protocol.

## The 13 profiles are not excess

Verified in hyprsunset 0.3.3's code: ZERO occurrences of transition/interpolate/gradual, and the
"Graduated transition" issue is still OPEN. It jumps hard at each profile's time.

A small, frequent step is the ONLY way to get a smooth curve out of a tool that only knows how to
jump. If it ever interpolates, this collapses to 3 profiles (see `docs/ideas.md`).

## How it runs

The `services.hyprsunset` module brings up a `systemd --user` SERVICE (no `exec-once` needed) and
generates `~/.config/hypr/hyprsunset.conf` from `settings`. The `profile` entries change the
temperature by clock time on their own; the F9 keybinds are just a one-off manual override through
`hyprctl hyprsunset`.

Kelvin reference: 6500 = a neutral day, 4000 = night, 3000 = late night, 2000 = the small hours.

`max-gamma = 150` gives slack above the default 100 for tuning through IPC, which is what
`brightness-osd` uses as its ceiling (see [`hypr.md`](hypr.md)).

## The night is aggressive on purpose

**06/08/2026**, a rewrite of the schedule inherited from Arch: I work all day on ANOTHER PC with no
filter, so by the time I get here at 18h my eyes are already beaten and there is no treating 18h as
"the start of a mild evening". The old schedule only came down 500K at a time and reached 5500K at
18h, close to neutral, which means real relief only at 22h, 4 h after arriving.

**A second descent, 13/08/2026**: the 06/08 one still felt weak, and this takes another ~200-400K
off each step after 18h. The biggest step is still the 18h one (5000 to 3800) and by 19h it is
already at 3200K, where the previous curve only arrived at 20h.

### The color axis was chosen, and it contradicts `docs/ideas.md`

That file records the priority as reducing BRIGHTNESS before color temperature. Going with color
was deliberate: the automatic dim through gamma existed once and was REVERTED on 08/08 along with
DDC, and bringing it back at 18h is a bigger change than lowering Kelvin.

If this curve is not enough, the NEXT step is progressive gamma from 18h onward, NOT continuing to
drop Kelvin, which from here down only ruins the color with no proportional relief.

### The curve crosses ~3200K on purpose

Below that the color is visibly orange and RUINS a movie, a game or a photo, and from 19h onward
that is the NORMAL state, not the exception.

So SUPER+SHIFT+F9 (`hyprctl hyprsunset identity`, the filter OFF) stops being a rare resource and
becomes the usual gesture when opening media at night; the clock's next profile picks the curve
back up on its own. If it gets in the way too much, the adjustment is raising ONLY the 18h/18:30
step, not flattening the whole curve.

## The gamma story, and why it dims both screens badly instead of one perfectly

`gamma` is PERCEIVED brightness (1.0 = normal, below 1 darkens), and it is the only automatic
dimming that reaches BOTH screens. It came back on 08/08/2026 after an attempt at using real
backlight was REVERTED.

**The attempt**: DP-2 accepts DDC/CI and got a real backlight curve, much better than gamma, which
darkens the SIGNAL with the backlight wide open. But the LG TV on HDMI does NOT speak DDC/CI, it is
not on the network (no webOS), and CEC does not cover brightness, so there is no automatic path for
it.

One screen at 32% next to another at 100% forces the pupil to readapt every time the gaze switches,
and that tires more than the gain on the good screen. **The decision: worse dimming on both beats
perfect dimming on one.** The measurement that motivated all of it (the monitor was at 100% at 20h)
is in `docs/history/2026/`.

So auto-dim runs ONLY at night: the day and early evening stay at full brightness, since I may be
working; from 22h onward it darkens down to 0.8 (the floor) and comes back in the morning.

**WARNING**: a profile WITHOUT `gamma` goes back to 1.0, because each profile resets what the
others set.
