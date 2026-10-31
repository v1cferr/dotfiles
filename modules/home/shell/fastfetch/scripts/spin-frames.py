"""Render the NixOS snowflake tumbling in 3D into ASCII frames, the way donut.c draws its torus.

The logo becomes a solid slab: front and back faces plus a rim whose normals come from the
outline. For each frame the solid rotates about two axes at once, every surface point is
projected with perspective into a z-buffer, and its luminance against a fixed light picks a
character from donut.c's ramp. The logo's own two blues tint the characters.

usage: spin-frames.py <logo.png> <rows> <frames> <outdir>
<outdir>/frames holds every frame separated by ASCII RS (0x1e), and <outdir>/first the first one
alone, for fastfetch to reserve the logo's space. Each frame is `rows` lines of exactly 2*rows
cells (a cell is about twice as tall as wide, so the logo stays round), which lets one frame be
drawn over the previous without clearing the screen.
"""

import math
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

RS = "\x1e"
RAMP = ".,-~:;=!*#$@"  # donut.c's, from dark to bright
THICKNESS = 0.14  # half the slab's depth, in logo radii
DISTANCE = 5.0  # viewer to the logo's center, in logo radii: mild perspective
BEVEL = 6.0  # how much the faces round off toward the outline, so a face is a gradient, not one glyph
LIGHT = np.array([0.0, 0.7, 0.7])  # from above and in front, like donut.c's (0, 1, -1)
LIGHT = LIGHT / np.linalg.norm(LIGHT)
TURNS_X, TURNS_Z = 2, 1  # whole turns per loop, so the last frame meets the first


def surface(path, side):
    """Surface points, their normals and their base colors, in logo radii."""
    img = Image.open(path).convert("RGBA").resize((side, side), Image.LANCZOS)
    rgba = np.asarray(img, dtype=np.float32) / 255.0
    mask = rgba[..., 3] > 0.5
    rgb = rgba[..., :3]

    # The blurred alpha's gradient points inward from the outline: it rounds the faces off (a
    # pillowed slab, the way the torus's curve shades donut.c) and gives the rim its normals.
    blur = np.asarray(
        Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(side / 60)),
        dtype=np.float32,
    )
    gy, gx = np.gradient(blur / 255.0 * side / 60)

    ys, xs = np.nonzero(mask)
    x = (xs - side / 2 + 0.5) / (side / 2)
    y = -(ys - side / 2 + 0.5) / (side / 2)
    col = rgb[ys, xs]
    n = len(x)
    tilt_x, tilt_y = -gx[ys, xs] * BEVEL, gy[ys, xs] * BEVEL
    front = np.stack([tilt_x, tilt_y, np.ones(n)], 1)
    back = np.stack([tilt_x, tilt_y, -np.ones(n)], 1)
    front /= np.linalg.norm(front, axis=1, keepdims=True)
    back /= np.linalg.norm(back, axis=1, keepdims=True)
    pts = [np.stack([x, y, np.full(n, THICKNESS)], 1), np.stack([x, y, np.full(n, -THICKNESS)], 1)]
    nrm = [front, back]
    cols = [col, col]

    # The rim: outline pixels, facing outward.
    edge = mask & ~np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)), dtype=bool)
    ey, ex = np.nonzero(edge)
    en = np.stack([-gx[ey, ex], gy[ey, ex], np.zeros(len(ex))], 1)
    en /= np.maximum(np.linalg.norm(en, axis=1, keepdims=True), 1e-6)
    exn = (ex - side / 2 + 0.5) / (side / 2)
    eyn = -(ey - side / 2 + 0.5) / (side / 2)
    for z in np.linspace(-THICKNESS, THICKNESS, 9)[1:-1]:
        pts.append(np.stack([exn, eyn, np.full(len(ex), z)], 1))
        nrm.append(en)
        cols.append(rgb[ey, ex])
    return np.concatenate(pts), np.concatenate(nrm), np.concatenate(cols)


def rotation(a, b):
    """About X by a, then about Z by b: donut.c's two angles."""
    ca, sa, cb, sb = math.cos(a), math.sin(a), math.cos(b), math.sin(b)
    rx = np.array([[1, 0, 0], [0, ca, -sa], [0, sa, ca]])
    rz = np.array([[cb, -sb, 0], [sb, cb, 0], [0, 0, 1]])
    return rz @ rx


def frame(pts, nrm, cols, rows, a, b):
    """One frame as `rows` lines of 2*rows tinted characters."""
    width = 2 * rows
    r = rotation(a, b)
    p, n = pts @ r.T, nrm @ r.T
    ooz = 1.0 / (DISTANCE - p[:, 2])  # toward the viewer is +z
    scale = (rows / 2 - 0.5) * (DISTANCE - 1.0)  # the nearest point still fits
    sx = np.floor(width / 2 + 2 * scale * p[:, 0] * ooz).astype(int)
    sy = np.floor(rows / 2 - scale * p[:, 1] * ooz).astype(int)
    inside = (sx >= 0) & (sx < width) & (sy >= 0) & (sy < rows)
    lum = n @ LIGHT

    # The z-buffer, vectorized: sort by cell and then by 1/z, and keep each cell's last (nearest).
    idx = np.nonzero(inside)[0]
    cell = sy[idx] * width + sx[idx]
    idx = idx[np.lexsort((ooz[idx], cell))]
    cell = sy[idx] * width + sx[idx]
    last = np.append(cell[1:] != cell[:-1], True)
    idx, cell = idx[last], cell[last]

    char = np.full(rows * width, -1)
    tint = np.zeros((rows * width, 3))
    char[cell] = np.clip((lum[idx] * len(RAMP)).astype(int), 0, len(RAMP) - 1)
    tint[cell] = cols[idx]
    return char.reshape(rows, width), tint.reshape(rows, width, 3)


def encode(char, tint):
    """Tinted lines, emitting a color only when it changes."""
    lines = []
    for y in range(char.shape[0]):
        out, last = [], None
        for x in range(char.shape[1]):
            if char[y, x] < 0:
                out.append(" ")
                continue
            # Two shades per hue are enough to read as the logo and keep the frames small.
            c = tuple(int(round(v * 255 / 32) * 32) for v in tint[y, x])
            c = tuple(min(255, v) for v in c)
            if c != last:
                out.append("\x1b[38;2;%d;%d;%dm" % c)
                last = c
            out.append(RAMP[char[y, x]])
        out.append("\x1b[0m")
        lines.append("".join(out))
    return "\n".join(lines)


def main():
    path, rows, frames, dest = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    pts, nrm, cols = surface(path, 8 * rows)  # dense enough to leave no holes when tilted
    out = []
    for k in range(frames):
        t = 2 * math.pi * k / frames
        out.append(encode(*frame(pts, nrm, cols, rows, TURNS_X * t, TURNS_Z * t)))
    os.makedirs(dest, exist_ok=True)
    with open(os.path.join(dest, "frames"), "w", encoding="utf-8") as f:
        f.write(RS.join(out))
    with open(os.path.join(dest, "first"), "w", encoding="utf-8") as f:
        f.write(out[0] + "\n")


if __name__ == "__main__":
    main()
