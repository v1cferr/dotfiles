# fastfetch: boxes for a screenshot, and a logo that tumbles like donut.c

Module: [`modules/home/shell/fastfetch/default.nix`](../../../modules/home/shell/fastfetch/default.nix)

fastfetch is run to screenshot the rice for r/NixOS and r/unixporn, so what it shows is picked for
whoever looks at the picture: the nixpkgs pin, the Nix version and the closure size, the pieces of
the rice that fastfetch cannot detect (bar, launcher, prompt, editor), and no network address.

## The boxes

Each section is a box closed on both sides. fastfetch has no per-line suffix, and its format
padding counts bytes and not cells, so the right border is drawn from the key: save the cursor
(ESC 7), jump over the value column, print the border, and restore (ESC 8). The value then prints
in between. A value longer than the column (46 cells) overwrites the border, which is why the CPU,
the displays and the themes use trimmed formats.

Every module prints exactly one line, so the module list's length is the boxes' height. That is
what keeps the displays as one row per connector (fastfetch cannot sort displays, and the order
comes from `my.monitors`) and the font as kitty's declared one (`terminalfont` prints nothing
outside kitty, which shifted every row).

## The tumbling logo

The logo is drawn the way [donut.c](https://www.a1k0n.net/2011/07/20/donut-math.html) draws its
torus, and fastfetch cannot animate a logo, so every frame is rendered at build time by
[`spin-frames.py`](../../../modules/home/shell/fastfetch/scripts/spin-frames.py):

- The official snowflake becomes a solid slab: front and back faces, rounded off toward the
  outline so each face is a gradient and not a single glyph, plus a rim facing outward.
- It rotates about two axes at once at donut.c's pace (0.04 rad about X and 0.02 about Z per
  frame), which makes two turns about X for one about Z in 314 frames: the loop has no seam.
- Each surface point is projected with perspective into a z-buffer, and its brightness against a
  fixed light picks a character from donut.c's ramp, `.,-~:;=!*#$@`, with its `L*8` mapping. The logo's two blues tint
  the characters.
- A frame is as tall as the boxes and twice as wide, since a cell is about twice as tall as wide.

The zsh wrapper prints the boxes with the first frame as the logo, so fastfetch reserves exactly
its space, and then redraws the frames over it from the bottom of the output until a key. The key
goes on to the prompt.

## The layout follows the terminal

| Terminal | What prints |
| --- | --- |
| 143+ columns, taller than the boxes, a terminal on both ends | the spinning logo and the boxes |
| 64+ columns | the boxes alone |
| narrower | the plain list, from the same modules in another style |

A logo taller than the window breaks fastfetch, which draws the logo first and climbs back up to
print the boxes beside it; a scrolled screen cannot be climbed. Arguments (`fastfetch --help`) and a
redirected output skip the animation.
