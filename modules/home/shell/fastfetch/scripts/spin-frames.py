"""Render the NixOS snowflake spinning around its vertical axis into terminal frames.

The logo becomes a slab with some thickness, splatted voxel by voxel into a z-buffer for each
angle, then shaded per face (front, back, rim) and written as half-block cells: the upper pixel is
the foreground of "▀" and the lower one its background, so a cell holds two square pixels.

usage: spin-frames.py <logo.png> <rows> <frames> <outdir>
<outdir>/frames holds every frame separated by ASCII RS (0x1e), and <outdir>/first the front-facing
one alone, for fastfetch to reserve the logo's space. Each frame is `rows` lines of exactly 2*rows
cells, so drawing one over the previous erases it without clearing the screen.
"""

import math
import os
import sys

import numpy as np
from PIL import Image

RS = "\x1e"
SUPER = 2  # supersampling per output pixel, so the edges come out antialiased into coverage
THICKNESS = 0.06  # of the logo's width: about 3 cells when seen edge-on
LIGHT = np.array([-0.35, -0.45, 0.82])  # from the viewer's upper left
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def load(path, size):
    """The logo's colors and alpha mask at size x size."""
    img = Image.open(path).convert("RGBA").resize((size, size), Image.LANCZOS)
    rgba = np.asarray(img, dtype=np.float32) / 255.0
    return rgba[..., :3], rgba[..., 3] > 0.5


def render(rgb, mask, theta, size):
    """One angle into an RGB image plus coverage, both at size x size."""
    ys, xs = np.nonzero(mask)
    base = rgb[ys, xs]
    cx = (xs - size / 2 + 0.5).astype(np.float32)
    cy = (ys - size / 2 + 0.5).astype(np.float32)
    half = THICKNESS * size / 2
    layers = max(2, int(round(THICKNESS * size)) + 1)
    c, s = math.cos(theta), math.sin(theta)

    depth = np.full((size, size), -np.inf, dtype=np.float32)
    color = np.zeros((size, size, 3), dtype=np.float32)
    for i, z in enumerate(np.linspace(-half, half, layers)):
        px = cx * c + z * s  # rotation about Y: x' = x cos + z sin, depth = -x sin + z cos
        pz = -cx * s + z * c
        if i == layers - 1:
            normal = np.array([s, 0.0, c])  # front face
        elif i == 0:
            normal = np.array([-s, 0.0, -c])  # back face
        else:
            normal = None  # rim: only shows at the silhouette
        if normal is not None:
            shade = 0.30 + 0.70 * max(0.0, float(normal @ LIGHT))
        else:
            shade = 0.42
        sx = np.clip(np.round(px + size / 2 - 0.5).astype(int), 0, size - 1)
        sy = np.clip(np.round(cy + size / 2 - 0.5).astype(int), 0, size - 1)
        # Nearest voxel wins: sort far to near, so later writes are the closer ones.
        order = np.argsort(pz)
        sx, sy, pz_o = sx[order], sy[order], pz[order]
        closer = pz_o > depth[sy, sx]
        sx, sy, pz_o = sx[closer], sy[closer], pz_o[closer]
        depth[sy, sx] = pz_o
        color[sy, sx] = base[order][closer] * shade
    return color, np.isfinite(depth)


def downsample(color, cover, factor):
    """Average factor x factor blocks; a pixel is on when at least half of its block is."""
    h, w = cover.shape
    cov = cover.reshape(h // factor, factor, w // factor, factor).mean(axis=(1, 3))
    col = (color * cover[..., None]).reshape(h // factor, factor, w // factor, factor, 3).sum(axis=(1, 3))
    col = col / np.maximum(cov * factor * factor, 1e-6)[..., None]
    return col, cov >= 0.5


def encode(col, on):
    """Half-block lines, emitting a color only when it changes."""
    lines = []
    for r in range(0, on.shape[0], 2):
        out, fg, bg = [], None, None
        for x in range(on.shape[1]):
            top, bot = on[r, x], on[r + 1, x]
            tc = tuple(int(v * 255) for v in col[r, x]) if top else None
            bc = tuple(int(v * 255) for v in col[r + 1, x]) if bot else None
            if top:
                want_fg, want_bg, ch = tc, bc, "▀"
            elif bot:
                want_fg, want_bg, ch = bc, None, "▄"
            else:
                want_fg, want_bg, ch = fg, None, " "
            if want_bg != bg:
                out.append("\x1b[49m" if want_bg is None else "\x1b[48;2;%d;%d;%dm" % want_bg)
                bg = want_bg
            if want_fg != fg and ch != " ":
                out.append("\x1b[38;2;%d;%d;%dm" % want_fg)
                fg = want_fg
            out.append(ch)
        out.append("\x1b[0m")
        lines.append("".join(out))
    return "\n".join(lines)


def main():
    path, rows, frames, dest = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    side = 2 * rows  # pixels per side: 2 per cell vertically, 1 per cell horizontally
    size = side * SUPER
    rgb, mask = load(path, size)
    out = []
    for n in range(frames):
        color, cover = render(rgb, mask, 2 * math.pi * n / frames, size)
        out.append(encode(*downsample(color, cover, SUPER)))
    os.makedirs(dest, exist_ok=True)
    with open(os.path.join(dest, "frames"), "w", encoding="utf-8") as f:
        f.write(RS.join(out))
    with open(os.path.join(dest, "first"), "w", encoding="utf-8") as f:
        f.write(out[0] + "\n")


if __name__ == "__main__":
    main()
