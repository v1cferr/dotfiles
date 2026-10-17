# Motion: Smooth and Subtle

How the desktop moves, across Hyprland (`modules/home/desktop/hypr/lua/appearance.lua`) and
Quickshell (`modules/home/desktop/quickshell/Theme.qml` plus its consumers). One motion language for
both, written down here so the two halves cannot drift apart.

## The aim

Calm while I am concentrating, responsive when I touch something. The reference is the restraint of
macOS plus the easing of [motion.dev](https://motion.dev/), used as a DESIGN reference and never as a
dependency. In practice that means:

- **Fast in, faster out.** An entrance is short and decelerates; an exit is shorter still, because
  nobody waits to watch a thing leave.
- **No visible overshoot, ever.** No bounce, no rubber band, no zoom that draws the eye.
- **Springs for space, curves for everything else.** Something that MOVES (a window settling on the
  tape, a workspace sliding) gets a near-critically damped spring, which keeps its velocity when it
  is retargeted mid-flight. Opacity and color get a short ease-out.
- **Never on a refresh.** An entrance plays once, when a thing appears; data that updates (a clock,
  CPU, RAM, the weather) changes in place.
- **No decoration that never stops**, except a status that IS motion (an activity badge, a failing
  service), which is information and stays on in every profile.

## The switch: `my.theme.motion`

`my.theme.motion` (`palette.nix`) is `"subtle"` (the default, everything below) or `"off"`. It
lives in `my.theme` because motion is theming that is not color, and it rides the two files the
hot-reload consumers already read (`~/.config/theme/hypr-colors.lua` and
`quickshell-colors.json`), so it is ONE value with two readers (rule 11), never a second option.

There is deliberately no third, "expressive" profile: the brief was subtle, and a profile nobody
uses is dead config (rule 16).
