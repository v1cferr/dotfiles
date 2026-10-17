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

## Hyprland

Three curves, and every leaf names one of them:

| Curve | Definition | Used for |
| --- | --- | --- |
| `settle` | spring, mass 1, stiffness 700, dampening 49 | what MOVES: `windows` (and `windowsMove` through it), `workspaces` |
| `easeOutQuint` | bezier (0.23, 1), (0.32, 1) | entrances: `windowsIn`, `border`, `layers`, `fadeLayersIn`, `specialWorkspace` |
| `almostLinear` | bezier (0.5, 0.5), (0.75, 1) | opacity and exits: `fade`, `fadeIn`, `fadeOut`, `windowsOut`, `layersOut`, `fadeLayersOut` |

| Leaf | Before (until 17/10/2026) | Now |
| --- | --- | --- |
| `windows` / `windowsMove` | 479 ms easeOutQuint | `settle` spring (~310 ms to rest) |
| `windowsIn` | 410 ms, `popin 87%` | 220 ms easeOutQuint, `popin 97%` |
| `windowsOut` | 149 ms linear, `popin 87%` | 130 ms almostLinear, `popin 97%` |
| `fade` (focus, dim, shadow, popups) | 303 ms `quick` | 200 ms almostLinear |
| `fadeIn` / `fadeOut` | 173 / 146 ms | 180 / 120 ms |
| `border` | 539 ms | 200 ms easeOutQuint |
| `layers` (in) / `layersOut` | 400 / 150 ms, `fade` | 160 / 100 ms, `fade` |
| `fadeLayersIn` / `fadeLayersOut` | 179 / 139 ms almostLinear | 150 ms easeOutQuint / 100 ms almostLinear |
| `workspaces` | 121 to 194 ms almostLinear, `fade` | `settle` spring, `slidefade 8%` |
| `specialWorkspace` | (inherited `fade`) | 180 ms easeOutQuint, `fade`, pinned so the slide does not reach it |

**Why a spring only for space.** A Hyprland spring IGNORES `speed`: its duration comes out of the
physics (`hyprutils/src/animation/Spring.cpp`), and a retarget keeps the velocity it had. That is
exactly what the scrolling tape wants, where SUPER+scroll can fire a second column jump before the
first one landed: a bezier restarts at zero velocity and stutters, the spring bends. For an opacity there
is nothing to retarget, so a plain curve with a known duration is the honest choice.

**Why these spring numbers.** The damping ratio is `c / (2 * sqrt(k * m))`; 49 / (2 * sqrt(700))
is 0.93, just under critical. Integrated with the same model hyprutils uses (180 Hz steps, its
0.001 value and velocity epsilons), REASONED and not measured on screen, on 17/10/2026:

| Spring | zeta | 90% | 99% | at rest | overshoot |
| --- | --- | --- | --- | --- | --- |
| upstream example `easy` (238 / 24.2) | 0.78 | 194 ms | 450 ms | 650 ms | 1.85% |
| critical (500 / 44.7) | 1.00 | 178 ms | 333 ms | 567 ms | 0 |
| **`settle` (700 / 49)** | **0.93** | **133 ms** | **206 ms** | **306 ms** | **0.06%** |

Exactly critical looks right on paper and wrong on a compositor: its tail is exponential, so the
window is visibly "still arriving" for half a second and Hyprland keeps drawing frames until the
epsilon is met. A touch under critical reaches rest in half the time, and 0.06% of a 2560 px
workspace slide is 1.5 px, below what the eye resolves at that speed. The upstream example spring
at 0.78 overshoots almost 2%, which on a window edge IS the rubber band the brief rules out.

**The `dampening` trap.** The wiki and Hyprland's main branch spell the field `damping`, but the
pinned 0.56.2 reads only `dampening` and rejects a spring without it. Main renamed it on
29/08/2026 (#15993) and still falls back to `dampening`, so the old spelling is the one that works
on both sides of the next bump.

**The popin is 97%, not 87%.** Hyprland's popin scales from the center, and on a 2560 px column
87% means the edges travel 166 px each, a zoom you notice. 97% is 38 px: the window settles into
place instead of arriving from somewhere.

**Workspaces slide 8%.** `slidefade 8%` moves the outgoing and incoming workspace 8% of the
monitor's width (205 px on the primary) while they cross-fade, enough to say which way you went
and nowhere near a full-screen slide, which on an infinite tape would compete with the tape's own
horizontal motion. The direction follows the workspace id.

**Measured, 17/10/2026, on the ASUS at 180 Hz** (scratch scripts, `/proc/<pid>/stat` utime plus
stime over the run, old block restored from git for the comparison):

| Test | Old curves | New curves |
| --- | --- | --- |
| 30 workspace switches 120 ms apart (3 runs) | 13.4 to 13.7% of a core | 13.4 to 14.1% |
| 6 kitty open and close cycles on an empty workspace (2 runs) | 7.2 to 7.6% | 6.8 to 7.2% |

The same within noise: the spring's longer settle tail is not a cost. Every run ended on the
workspace it started on with no window left behind. What these numbers cannot say is how it LOOKS;
there is no frame-pacing tool in the repo, and no dropped-frame count was taken.

### What is left alone

- **Flameshot's overlay** keeps `no_anim` (`rules.lua`): a frozen screenshot must not zoom in.
- **Games and Picture-in-Picture** have no animation rule of their own and none was added. A
  fullscreen toggle runs through `windowsMove`, so it now settles on the spring instead of a
  479 ms bezier. `render_unfocused` and `render_unfocused_fps` are untouched.
- **The lock screen** is a session lock, not a layer, and no animation leaf touches it.
- **No `borderangle` loop**: the wiki's own warning applies (it renders every frame forever).
- **`zoomFactor` and `monitorAdded`** keep the `global` default; nothing here uses them.

### Off in Hyprland

With `my.theme.motion = "off"` the module sets `animations.enabled = false`, the one switch
Hyprland has for all of it. Every leaf stays declared, so going back is the same option.

## Vicinae

Until 17/10/2026 the launcher's layer carried `no_anim`, so SUPER+Q felt instant. It now carries
`animation = "fade"`: no movement at all, 150 ms of easeOutQuint opacity in (`fadeLayersIn`) and
100 ms out (`fadeLayersOut`). The style is pinned on the rule, not inherited, so a later change to
`layers` can never make the launcher zoom.

**Does the compositor even see the toggle?** Yes. `vicinae open` creates a layer surface named
`vicinae` and `vicinae close` destroys it (`hyprctl layers` goes from nothing to one 1024x644 surface
and back), so every toggle is a map and an unmap, and layer rules apply to it. Vicinae itself has
no animation setting (`vicinae config default` has none), so this rule is the only lever.

**Does the fade cost input latency?** No, by construction and by measurement. In 0.56.2
`CLayerSurface::onMap()` hands keyboard focus to the layer BEFORE it applies the entrance
animation, so the first keystroke reaches the search field on the first frame, whatever the
opacity is. Measured on 17/10/2026, `vicinae open` to the layer listed by Hyprland, 8 opens each:

| Rule | exec to mapped |
| --- | --- |
| `no_anim` (before) | 12 to 14 ms |
| `animation = "fade"` | 12 to 14 ms |

The fade starts on top of that, and easeOutQuint puts it past half opacity within roughly the
first 20 ms, so the launcher reads as present on the same frame it would have before.

**Rapid toggling.** 20 `vicinae toggle` calls back to back, then a check: the number of `vicinae`
layers matched Vicinae's own `vicinae state open` every time, under both rules, and none was left
behind after a close. A surface that unmaps mid-fade is drawn out of its last frame by Hyprland and
is gone 100 ms later; it never takes input. One thing this test showed that is NOT ours: under
that spam Vicinae's own IPC drops some toggles, so 20 toggles do not always end closed. It happened
with `no_anim` too.

**If it ever feels slower**, the revert is the one line in `rules.lua` back to `no_anim = true`;
an instant launcher beats an animated one, and that was the condition this was accepted under.

## Quickshell

Durations live in `Theme.qml` as tokens, one per MEANING, and a consumer never holds a literal:

| Token | Value | Meaning | Used by |
| --- | --- | --- | --- |
| `motionFast` | 90 ms | a direct answer to a key | the OSD's volume and brightness bars |
| `motionHover` | 120 ms | a hover's color or border | pills, workspace buttons, menu rows, notification buttons |
| `motionNormal` | 180 ms | something appearing or moving | popovers, the workspace indicator, a toast, page dots |
| `motionSlow` | 300 ms | a value settling | meters, the media progress bar, the CPU cores |
| `ms(d)` | `d` | a one-off that still obeys `off` | the glance band's own choreography (below) |

All of them are `NumberAnimation`/`ColorAnimation` with an ease-out, deliberately. Qt's
`SpringAnimation` was weighed for the moving parts and rejected: it is tuned by `spring`/`damping`
values with no duration, which is the opposite of what a token needs, and nothing in the shell is
retargeted fast enough for velocity to matter. A Behavior already restarts from where the value IS.

**The glance band keeps its own numbers** (the 320/560 ms entrance, 420 ms page slides, the
520 ms services rail, the 1100 ms weather draw-in), wrapped in `Theme.ms()`: they were chosen as
one choreography on 07/10/2026 ([dash.md](dash.md#motion)), they play when a page turns on its
own and not when I act, and folding them into the shell's tokens would retune a design that works.

### Off in Quickshell

`my.theme.motion = "off"` reaches `Theme.motionReduced`, and every token and `ms()` returns 0, so
each Behavior jumps straight to its value. The decorative loop (`WeatherAmbient`'s sun and rain)
stops. What does NOT stop is a pulse that is a status: the workspace activity badge, a running CI
job, a failing service, a tile past its limit, an INMET alert. Those carry information, and
removing their motion would remove the signal.

Tested on 17/10/2026 by a probe in `shell.qml` against the live shell: `subtle` resolved to
90/120/180/300 and `off` to 0 everywhere, with no QML error on either reload (the probe and the
forced fallback were reverted).
