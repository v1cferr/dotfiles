"""Lockscreen v2: localized glass PRE-RENDERED over static wallpapers, never on the lock path.
`prepare` renders and publishes the next set; `fallback` runs at build time. docs/notes/desktop/lockscreen.md"""

import argparse
import fcntl
import hashlib
import json
import os
import random
import shutil
import subprocess
import sys
import time
import unicodedata
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

# Part of every cache key: bump it when the pixels this file draws change.
RENDERER_VERSION = "3.0.0"

# A photo is decoded through draft() at the screen's size, so a big one is not a bomb here.
Image.MAX_IMAGE_PIXELS = 400_000_000
# How much the source may be upscaled to cover a screen before it is refused (blurry art).
MAX_UPSCALE = 1.5
# A source this far from the screen's aspect is a different orientation.
LANDSCAPE, PORTRAIT = 1.2, 0.85
SUPERSAMPLE = 4  # the rounded mask and the hairline, drawn 4x and reduced: antialiased edges
# Over WCAG's number: the 95th percentile of a reduced patch is not the single worst pixel.
MARGIN = 1.1
KEEP_SETS = 3
BUDGET_BYTES = 256 * 1024 * 1024
LEGACY = ("quotes", "weather", "secondary", "quotes.tmp", "weather.tmp")


# ── Color and contrast (WCAG 2) ─────────────────────────────────────────────────────────────


def rgb(hexstr: str) -> tuple:
    h = hexstr.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def _lin(c: float) -> float:
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


LIN = [_lin(i) for i in range(256)]


def luminance(c: tuple) -> float:
    return 0.2126 * LIN[c[0]] + 0.7152 * LIN[c[1]] + 0.0722 * LIN[c[2]]


def contrast(a: float, b: float) -> float:
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def bright_luminance(img: Image.Image, pct: float = 0.95) -> float:
    """The luminance of the brightest (1 - pct) of the pixels: the worst case under light text."""
    small = img.convert("RGB")
    if small.width * small.height > 40000:
        f = (small.width * small.height / 40000) ** 0.5
        small = small.resize(
            (max(1, int(small.width / f)), max(1, int(small.height / f))), Image.BOX
        )
    pixels = small.get_flattened_data() if hasattr(small, "get_flattened_data") else small.getdata()
    lum = sorted(luminance(p) for p in pixels)
    return lum[min(len(lum) - 1, int(pct * len(lum)))]


# ── Geometry ────────────────────────────────────────────────────────────────────────────────


def card_rect(card: dict, size: tuple) -> tuple:
    """A card's box in monitor-local pixels: (left, top, right, bottom)."""
    w, h = size
    cx, cy = w / 2 + card["center"][0], h / 2 + card["center"][1]
    cw, ch = card["size"]
    return (round(cx - cw / 2), round(cy - ch / 2), round(cx + cw / 2), round(cy + ch / 2))


def check_layout(cards: list, size: tuple) -> list:
    """Problems with a layout on a screen: a card outside it, or two cards overlapping."""
    problems = []
    rects = [(c["id"], card_rect(c, size)) for c in cards]
    for cid, (x0, y0, x1, y1) in rects:
        if x0 < 0 or y0 < 0 or x1 > size[0] or y1 > size[1]:
            problems.append(f"{cid} leaves the {size[0]}x{size[1]} screen")
    for i, (a, ra) in enumerate(rects):
        for bid, rb in rects[i + 1 :]:
            if ra[0] < rb[2] and rb[0] < ra[2] and ra[1] < rb[3] and rb[1] < ra[3]:
                problems.append(f"{a} overlaps {bid}")
    return problems


def logical_size(mon: dict) -> tuple:
    """hyprctl's width/height are the MODE; rotate for transforms 1/3/5/7 and divide by the scale."""
    w, h = mon["width"], mon["height"]
    if mon.get("transform", 0) % 2 == 1:
        w, h = h, w
    s = mon.get("scale", 1) or 1
    return (round(w / s), round(h / s))


def live_sizes(spec: dict) -> dict:
    """The live logical size per role, from the running compositor; a role it lacks is absent."""
    try:
        out = subprocess.run(
            ["hyprctl", "-j", "monitors"], capture_output=True, text=True, timeout=5
        )
        mons = json.loads(out.stdout)
    except (OSError, ValueError, subprocess.SubprocessError):
        return {}
    by_name = {m.get("name"): m for m in mons if isinstance(m, dict)}
    sizes = {}
    for role, mon in spec["monitors"].items():
        if mon["name"] in by_name:
            sizes[role] = logical_size(by_name[mon["name"]])
    return sizes


# ── Wallpapers ──────────────────────────────────────────────────────────────────────────────


def probe(path: Path):
    """(width, height) from the header, or None for anything Pillow cannot identify."""
    try:
        with Image.open(path) as im:
            return im.size
    except (OSError, ValueError, Image.DecompressionBombError):
        return None


def suits(dims: tuple, size: tuple) -> int:
    """0 = refuse; 2 = the right orientation; 1 = usable through a crop (portrait screens only)."""
    w, h = dims
    scale = max(size[0] / w, size[1] / h)
    if scale > MAX_UPSCALE:
        return 0
    aspect = w / h
    if size[0] >= size[1]:
        return 2 if aspect >= LANDSCAPE else 0
    if aspect <= PORTRAIT:
        return 2
    return 1


def candidates(pools: list) -> list:
    files = []
    for pool in pools:
        p = Path(pool)
        if p.is_dir():
            files += sorted(
                f for f in p.iterdir()
                if f.is_file() and not f.name.startswith(".") and f.suffix.lower() != ".json"
            )
    return files


def pick(rng: random.Random, files: list, size: tuple, bad: set):
    """A random file of the best available grade; None when the pools hold nothing usable."""
    graded = {1: [], 2: []}
    for f in files:
        if f in bad:
            continue
        dims = probe(f)
        g = suits(dims, size) if dims else 0
        if g:
            graded[g].append(f)
    pool = graded[2] or graded[1]
    return rng.choice(pool) if pool else None


def sidecar(path: Path) -> dict:
    """The photo's facts, `<name>.json` beside it (the wallpaper captions' format plus `focus`)."""
    try:
        data = json.loads(path.with_suffix(".json").read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def focus_of(meta: dict) -> tuple:
    f = meta.get("focus")
    if isinstance(f, list) and len(f) == 2 and all(isinstance(v, (int, float)) for v in f):
        return (min(1.0, max(0.0, float(f[0]))), min(1.0, max(0.0, float(f[1]))))
    return (0.5, 0.5)


def open_for(path: Path, size: tuple) -> Image.Image:
    """Decode only what the cover needs: JPEG's DCT scaling turns a 123 Mpx photo into a few."""
    im = Image.open(path)
    w, h = im.size
    s = max(size[0] / w, size[1] / h)
    im.draft("RGB", (max(size[0], round(w * s)), max(size[1], round(h * s))))
    im.load()
    return im


def cover(img: Image.Image, size: tuple, focus: tuple) -> Image.Image:
    """Scale to COVER the screen and crop around the focal point, never past the image's edge."""
    w, h = img.size
    s = max(size[0] / w, size[1] / h)
    nw, nh = max(size[0], round(w * s)), max(size[1], round(h * s))
    img = img.resize((nw, nh), Image.LANCZOS)
    left = min(max(0, round(focus[0] * nw - size[0] / 2)), nw - size[0])
    top = min(max(0, round(focus[1] * nh - size[1] / 2)), nh - size[1])
    return img.crop((left, top, left + size[0], top + size[1]))


# ── Glass ───────────────────────────────────────────────────────────────────────────────────


def gradient(size: tuple, top: tuple, foot: tuple) -> Image.Image:
    """A vertical two-stop RGBA ease, GlassSurface's Gradient: one column stretched across."""
    w, h = size
    col = Image.new("RGBA", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        col.putpixel((0, y), tuple(round(top[i] + (foot[i] - top[i]) * t) for i in range(4)))
    return col.resize((w, h), Image.NEAREST)


def rounded_mask(size: tuple, radius: int) -> Image.Image:
    w, h = size
    big = Image.new("L", (w * SUPERSAMPLE, h * SUPERSAMPLE), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        (0, 0, w * SUPERSAMPLE - 1, h * SUPERSAMPLE - 1), radius * SUPERSAMPLE, fill=255
    )
    return big.resize((w, h), Image.LANCZOS)


def edges(size: tuple, radius: int, edge: tuple, rim: tuple, sheen: tuple, hairline: int) -> Image.Image:
    """The optical rim: a hairline, light that fades from the top edge to mid-height, and the 1 px
    sheen along the top, inset past the corners. Drawn 4x and reduced, so the curves stay clean."""
    w, h = size
    s = SUPERSAMPLE
    box = (0, 0, w * s - 1, h * s - 1)
    big = Image.new("RGBA", (w * s, h * s), (0, 0, 0, 0))
    ImageDraw.Draw(big).rounded_rectangle(box, radius * s, outline=edge, width=hairline * s)
    # The lit rim: the same outline in the light color, faded by a vertical ramp.
    lit = Image.new("RGBA", (w * s, h * s), (0, 0, 0, 0))
    ImageDraw.Draw(lit).rounded_rectangle(box, radius * s, outline=rim, width=hairline * s)
    ramp = Image.linear_gradient("L").resize((1, h * s)).point(lambda v: max(0, 255 - 2 * v))
    lit.putalpha(Image.composite(lit.getchannel("A"), Image.new("L", lit.size, 0),
                                 ramp.resize((w * s, h * s))))
    layer = Image.alpha_composite(big, lit).resize((w, h), Image.LANCZOS)
    ImageDraw.Draw(layer).line(
        (radius, hairline, max(radius, w - radius - 1), hairline), fill=sheen, width=hairline
    )
    return layer


def glow(size: tuple, color: tuple, alpha: float, depth: float) -> Image.Image:
    """The soft highlight: light from above, strongest at the top edge and gone by `depth` of the height."""
    w, h = size
    stop = max(1, round(h * depth))
    col = Image.new("L", (1, h), 0)
    for y in range(stop):
        col.putpixel((0, y), round(255 * alpha * (1 - y / stop) ** 2))
    layer = Image.new("RGBA", (w, h), (*color, 0))
    layer.putalpha(col.resize((w, h)))
    return layer


def refract(frosted: Image.Image, mask_inner: Image.Image, strength: float) -> Image.Image:
    """The rim's lens: the frosted image magnified by `strength` around its center, used only in
    the band between the edge and `mask_inner`. A whisper of depth, nothing that moves text."""
    w, h = frosted.size
    if strength <= 0:
        return frosted
    dw, dh = round(w * strength / 2), round(h * strength / 2)
    lens = frosted.crop((dw, dh, w - dw, h - dh)).resize((w, h), Image.BICUBIC)
    return Image.composite(frosted, lens, mask_inner)


def shadow(base: Image.Image, rect: tuple, radius: int, color: tuple, alpha: float, sigma: float, dy: int):
    """A soft shadow under a card, so it separates from the photo. Darkens, never blurs the photo."""
    x0, y0, x1, y1 = rect
    m = int(3 * sigma) + abs(dy) + 2
    box = (max(0, x0 - m), max(0, y0 - m + dy), min(base.width, x1 + m), min(base.height, y1 + m + dy))
    mask = Image.new("L", (box[2] - box[0], box[3] - box[1]), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (x0 - box[0], y0 - box[1] + dy, x1 - box[0] - 1, y1 - box[1] - 1 + dy), radius, fill=round(255 * alpha)
    )
    mask = mask.filter(ImageFilter.GaussianBlur(sigma))
    region = base.crop(box)
    base.paste(Image.composite(Image.new("RGB", region.size, color), region, mask), box[:2])


def dither(img: Image.Image, seed: int) -> Image.Image:
    """±1 level of seeded noise, so an 8-bit gradient over a dark blur does not band."""
    n = Image.frombytes("L", img.size, random.Random(seed).randbytes(img.width * img.height))
    up = n.point(lambda v: 255 if v % 3 == 2 else 0)
    down = n.point(lambda v: 255 if v % 3 == 0 else 0)
    img = Image.composite(img.point(lambda v: min(255, v + 1)), img, up)
    return Image.composite(img.point(lambda v: max(0, v - 1)), img, down)


def frost(region: Image.Image, glass: dict, bg: tuple) -> Image.Image:
    """HyprGlass's dark material, approximated: blur, its brightness and contrast, its bg tint."""
    out = region.filter(ImageFilter.GaussianBlur(glass["blurSigma"]))
    out = ImageEnhance.Brightness(out).enhance(glass["brightness"])
    out = ImageEnhance.Contrast(out).enhance(glass["contrast"])
    return Image.blend(out, Image.new("RGB", out.size, bg), glass["tint"])


def zones_of(card: dict, size: tuple) -> list:
    """Where the card's TEXT sits, card-relative (x, y, w, h); the inside past the padding by default."""
    w, h = size
    pad = min(24, w // 4, h // 4)
    return card.get("zones") or [[pad, pad, w - 2 * pad, h - 2 * pad]]


def zone_luminance(img: Image.Image, zones: list) -> float:
    """The worst (brightest 5%) luminance over the text zones together."""
    worst = 0.0
    for x, y, w, h in zones:
        if w > 0 and h > 0:
            worst = max(worst, bright_luminance(img.crop((x, y, x + w, y + h))))
    return worst


def glass_card(base: Image.Image, card: dict, spec: dict, seed: int) -> dict:
    """Composite one card into `base` in place; returns what was chosen and measured.
    Adaptive Glass+: frosted core, optical rim, soft highlight. docs/notes/desktop/lockscreen.md"""
    pal, glass, e = spec["palette"], spec["glass"], spec["edge"]
    bg, surface, text = rgb(pal["bg"]), rgb(pal["surface"]), rgb(pal["text"])
    x0, t, r, b = card_rect(card, base.size)
    w, h = r - x0, b - t
    radius = min(card["radius"], h // 2)
    zones = zones_of(card, (w, h))

    sh = spec.get("shadow")
    if sh and not glass["solid"] and card.get("edge", True):
        shadow(base, (x0, t, r, b), radius, rgb(pal["shadow"]), sh["alpha"], sh["sigma"], sh["dy"])

    hl = spec.get("highlight") or {"alpha": 0, "depth": 0.3}
    light = glow((w, h), text, hl["alpha"], hl["depth"])
    if glass["solid"]:
        body = Image.alpha_composite(Image.new("RGBA", (w, h), (*bg, 255)), light).convert("RGB")
        alpha = 1.0
    else:
        m = int(3 * glass["blurSigma"]) + 1
        box = (max(0, x0 - m), max(0, t - m), min(base.width, r + m), min(base.height, b + m))
        frosted = frost(base.crop(box), glass, bg).crop(
            (x0 - box[0], t - box[1], x0 - box[0] + w, t - box[1] + h)
        )
        band = spec.get("rimBand", 0)
        if band and w > 2 * band and h > 2 * band:
            inner = Image.new("L", (w, h), 0)
            ImageDraw.Draw(inner).rounded_rectangle(
                (band, band, w - band - 1, h - band - 1), max(0, radius - band), fill=255
            )
            frosted = refract(frosted, inner.filter(ImageFilter.GaussianBlur(band / 2)), spec.get("refraction", 0))
        # The card's own baseline first, denser only as far as the text needs: the lowest opacity at
        # which every text color keeps its target over the brightest 5% of the text ZONES.
        targets = card.get("contrast") or spec["contrast"]
        floor = max(card.get("alpha", glass["alphaMin"]), glass["alphaMin"])
        ceil = max(floor, glass["alphaMax"])
        steps = max(0, round((ceil - floor) / 0.02))
        foot = surface if glass["gradient"] else bg
        alpha, body = None, None
        for i in range(steps + 1):
            a = round(min(ceil, floor + 0.02 * i), 2)
            layer = gradient((w, h), (*bg, round(255 * a)), (*foot, round(255 * a)))
            trial = Image.alpha_composite(Image.alpha_composite(frosted.convert("RGBA"), layer), light)
            trial = trial.convert("RGB")
            worst = zone_luminance(trial, zones)
            if all(contrast(luminance(rgb(pal[k])), worst) >= v * MARGIN for k, v in targets.items()):
                alpha, body = a, trial
                break
        if body is None:
            alpha, body = ceil, trial
        body = dither(body, seed)

    over = body.convert("RGBA")
    if card.get("edge", True):
        over = Image.alpha_composite(
            over,
            edges(
                (w, h),
                radius,
                (*rgb(pal["border"]), round(255 * e["edge"])),
                (*text, round(255 * e.get("rim", 0))),
                (*text, round(255 * e["sheen"])),
                e["hairline"],
            ),
        )
    base.paste(over.convert("RGB"), (x0, t), rounded_mask((w, h), radius))

    worst = zone_luminance(base.crop((x0, t, r, b)), zones)
    return {
        "id": card["id"],
        "rect": [x0, t, r, b],
        "alpha": alpha,
        "contrast": {
            k: round(contrast(luminance(rgb(pal[k])), worst), 2)
            for k in ("text", "subtext", "accent", "red", "dim")
        },
    }


def load_logo(spec: dict):
    """The logo as a coverage mask cropped to its INK (an emblem off-center in its viewBox is centered
    by what is drawn), or None: it is decoration, and its absence must never stop a render."""
    lg = spec.get("logo")
    if not lg or not lg.get("path") or not Path(lg["path"]).is_file():
        return None
    try:
        png = subprocess.run(
            ["rsvg-convert", "-w", "1024", "-h", "1024", "--keep-aspect-ratio", lg["path"]],
            capture_output=True, check=True, timeout=20,
        ).stdout
        from io import BytesIO
        mask = Image.open(BytesIO(png)).convert("RGBA").getchannel("A")
    except (OSError, ValueError, subprocess.SubprocessError):
        return None
    box = mask.getbbox()
    return mask.crop(box) if box else None


def place_logo(base: Image.Image, mask: Image.Image, card: dict, lg: dict, color: tuple) -> list:
    """Fit the logo into a `size` square without distortion, centered on the card's axis at `dy`
    from its center, on whole pixels. Returns the rect it took (for the contrast zones)."""
    s = lg["size"]
    k = s / max(mask.size)
    w, h = max(1, round(mask.width * k)), max(1, round(mask.height * k))
    m = mask.resize((w, h), Image.LANCZOS)
    cx = round(base.width / 2 + card["center"][0])
    cy = round(base.height / 2 + card["center"][1] + lg["dy"])
    x, y = cx - w // 2, cy - h // 2
    base.paste(Image.new("RGB", (w, h), color), (x, y), m)
    return [x, y, x + w, y + h]


def compose(src: Image.Image, size: tuple, cards: list, spec: dict, focus: tuple, seed: int, logo=None):
    base = cover(src.convert("RGB"), size, focus)
    report = [glass_card(base, c, spec, seed + i) for i, c in enumerate(cards)]
    lg = spec.get("logo") or {}
    for c, rep in zip(cards, report):
        if logo is not None and c["id"] == lg.get("card"):
            rep["logo"] = place_logo(base, logo, c, lg, rgb(spec["palette"][lg.get("color", "text")]))
    return base, report


# ── Cache ───────────────────────────────────────────────────────────────────────────────────


def file_digest(path: Path, index: dict) -> str:
    """sha256 of the CONTENT; the (size, mtime) index only saves re-reading an unchanged file."""
    st = path.stat()
    stamp = [st.st_size, st.st_mtime_ns]
    hit = index.get(str(path))
    if hit and hit[0] == stamp:
        return hit[1]
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    index[str(path)] = [stamp, h.hexdigest()]
    return h.hexdigest()


def cache_key(digest: str, spec: dict, role: str, layout: str, size: tuple, focus: tuple) -> str:
    material = {
        "renderer": RENDERER_VERSION,
        "image": digest,
        "palette": spec["palette"],
        "glass": spec["glass"],
        "edge": spec["edge"],
        "material": {k: spec.get(k) for k in ("shadow", "highlight", "refraction", "rimBand")},
        "contrast": spec["contrast"],
        "cards": spec["monitors"][role]["layouts"][layout],
        "size": list(size),
        "focus": list(focus),
    }
    blob = json.dumps(material, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(blob).hexdigest()[:32]


def valid_png(path: Path, size: tuple) -> bool:
    try:
        with Image.open(path) as im:
            if im.size != tuple(size):
                return False
            im.load()
        return True
    except (OSError, ValueError):
        return False


def publish_file(data_writer, dest: Path) -> None:
    """Write to a temp name in the same directory, fsync, then rename: readers see all or nothing."""
    tmp = dest.with_name(f".{dest.name}.{os.getpid()}.tmp")
    try:
        with open(tmp, "wb") as f:
            data_writer(f)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, dest)
    finally:
        tmp.unlink(missing_ok=True)


def save_png(img: Image.Image, dest: Path) -> None:
    publish_file(lambda f: img.save(f, "PNG", compress_level=3), dest)


def swap_link(target: str, link: Path) -> None:
    tmp = link.with_name(f".{link.name}.{os.getpid()}.tmp")
    tmp.unlink(missing_ok=True)
    os.symlink(target, tmp)
    os.replace(tmp, link)


# ── Quotes ──────────────────────────────────────────────────────────────────────────────────

UNATTRIBUTED = {"", "unknown", "anonymous", "anônimo", "desconhecido", "zenquotes.io"}


def columns(text: str) -> int:
    """Monospace columns: East Asian wide and full-width characters take two."""
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in text)


def escape(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def wrap(text: str, width: int, max_lines: int):
    """Greedy word wrap by columns; None when it does not fit in max_lines (pick another)."""
    lines, cur = [], ""
    for word in " ".join(text.split()).split(" "):
        if columns(word) > width:
            return None
        cand = f"{cur} {word}" if cur else word
        if columns(cand) <= width:
            cur = cand
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines if 0 < len(lines) <= max_lines else None


def format_quote(q: dict, width: int, max_lines: int, author_color: str):
    """Pango markup for one quote, wrapped; the author only when there is a real one."""
    text = q.get("q") if isinstance(q, dict) else None
    if not isinstance(text, str) or not text.strip():
        return None
    lines = wrap(f"“{text.strip()}”", width, max_lines)
    if not lines:
        return None
    out = "<i>" + "\n".join(escape(x) for x in lines) + "</i>"
    author = q.get("a") if isinstance(q.get("a"), str) else ""
    if author.strip().lower() not in UNATTRIBUTED and columns(author) <= width:
        out += f'\n<span foreground="#{author_color}">{escape(author.strip())}</span>'
    return out


def choose_quote(path: Path, rng: random.Random, spec: dict) -> str:
    q = spec["quote"]
    try:
        batch = json.loads(path.read_text())
        batch = batch if isinstance(batch, list) else []
    except (OSError, ValueError):
        batch = []
    rng.shuffle(batch)
    for item in batch:
        out = format_quote(item, q["columns"], q["lines"], spec["palette"]["subtext"])
        if out:
            return out
    return format_quote(q["fallback"], q["columns"], q["lines"], spec["palette"]["subtext"])


# ── The two commands ────────────────────────────────────────────────────────────────────────


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def render_role(spec, role, layouts, size, rng, files, assets, index, bad, logo=None, logo_digest=""):
    """Render every layout of one monitor from ONE picked photo; {layout: asset path} or None."""
    for _ in range(5):
        src = pick(rng, files, size, bad)
        if src is None:
            return None, None
        try:
            digest = file_digest(src, index)
            focus = focus_of(sidecar(src))
            out = {}
            for layout in layouts:
                key = cache_key(digest + logo_digest, spec, role, layout, size, focus)
                dest = assets / f"{key}.png"
                if not valid_png(dest, size):
                    t0 = time.monotonic()
                    with open_for(src, size) as im:
                        img, report = compose(
                            im, size, spec["monitors"][role]["layouts"][layout], spec, focus,
                            int(key[:8], 16), logo,
                        )
                    save_png(img, dest)
                    meta = {"source": str(src), "size": list(size), "cards": report,
                            "credit": sidecar(src), "seconds": round(time.monotonic() - t0, 3)}
                    publish_file(lambda f: f.write(json.dumps(meta, indent=1).encode()),
                                 assets / f"{key}.json")
                    log(f"{role}/{layout}: rendered {src.name} in {meta['seconds']}s")
                else:
                    log(f"{role}/{layout}: cache hit for {src.name}")
                out[layout] = dest
            return out, src
        except (OSError, ValueError, Image.DecompressionBombError) as e:
            log(f"{role}: {src} is unusable ({e}), drawing another")
            bad.add(src)
    return None, None


def collect(cache: Path) -> None:
    """Drop old sets and the assets nothing references, then hold the byte budget."""
    sets, assets = cache / "sets", cache / "assets"
    keep = set()
    for link in ("ready", "session"):
        p = cache / link
        if p.is_symlink() or p.is_dir():
            keep.add(p.resolve())
    all_sets = sorted((s for s in sets.iterdir() if s.is_dir()), key=lambda s: s.stat().st_mtime)
    live_sets = set(all_sets[-KEEP_SETS:]) | {s for s in all_sets if s.resolve() in keep}
    for s in all_sets:
        if s not in live_sets:
            shutil.rmtree(s, ignore_errors=True)
    used = set()
    for d in list(live_sets) + [cache / "session"]:
        if d.is_dir():
            for f in d.iterdir():
                if f.is_symlink():
                    used.add(f.resolve().name)
    files = sorted(assets.glob("*.png"), key=lambda f: f.stat().st_mtime)
    for f in files:
        if f.name not in used:
            f.unlink(missing_ok=True)
            f.with_suffix(".json").unlink(missing_ok=True)
    for f in assets.glob(".*.tmp"):
        if time.time() - f.stat().st_mtime > 3600:
            f.unlink(missing_ok=True)
    total = sum(f.stat().st_size for f in assets.iterdir() if f.is_file())
    if total > BUDGET_BYTES:
        log(f"cache holds {total} bytes of referenced assets, over the {BUDGET_BYTES} budget")


def cmd_prepare(args) -> int:
    spec = json.loads(Path(args.spec).read_text())
    cache = Path(args.cache)
    for d in ("assets", "sets", "session"):
        (cache / d).mkdir(parents=True, exist_ok=True)
    with open(cache / ".lock", "w") as lockf:
        try:
            fcntl.flock(lockf, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            log("another prepare holds the cache, leaving it to that one")
            return 0
        rng = random.Random(args.seed)
        live = live_sizes(spec)
        idx_path = cache / "index.json"
        try:
            index = json.loads(idx_path.read_text())
        except (OSError, ValueError):
            index = {}
        index = {k: v for k, v in index.items() if Path(k).exists()}
        assets, bad = cache / "assets", set()
        logo = load_logo(spec)
        logo_digest = ""
        if logo is not None:
            logo_digest = ":logo:" + file_digest(Path(spec["logo"]["path"]), index) + json.dumps(spec["logo"], sort_keys=True)
        elif spec.get("logo"):
            log(f"logo {spec['logo'].get('path')} is missing or unreadable; the cards render without it")

        set_id = f"{time.time_ns()}-{os.getpid()}"  # ns: two runs in one process and one second
        stage = cache / "sets" / f".{set_id}.tmp"
        stage.mkdir()
        manifest = {"renderer": RENDERER_VERSION, "monitors": {}}
        for role, mon in spec["monitors"].items():
            size = live.get(role, tuple(mon["size"]))
            problems = [p for lay in mon["layouts"].values() for p in check_layout(lay, size)]
            if problems:
                log(f"{role}: {'; '.join(problems)}; the fallback stays for it")
                continue
            files = candidates(mon["pools"])
            out, src = render_role(spec, role, mon["layouts"], size, rng, files, assets, index, bad,
                                   logo, logo_digest)
            if not out:
                log(f"{role}: no usable photo in {mon['pools']}; the fallback stays for it")
                continue
            for layout, path in out.items():
                os.symlink(f"../../assets/{path.name}", stage / f"{role}-{layout}.png")
            manifest["monitors"][role] = {"source": str(src), "size": list(size),
                                          "live": role in live}
        quote = choose_quote(Path(spec["quotesFile"]), rng, spec)
        (stage / "quote").write_text(quote)
        (stage / "manifest.json").write_text(json.dumps(manifest, indent=1))
        final = cache / "sets" / set_id
        os.rename(stage, final)
        swap_link(f"sets/{set_id}", cache / "ready")
        publish_file(lambda f: f.write(json.dumps(index).encode()), idx_path)
        collect(cache)
        for name in LEGACY:
            (cache.parent / name).unlink(missing_ok=True)
    return 0


def cmd_fallback(args) -> int:
    """Build time: the packaged art per role, so the lock has glass even with an empty cache."""
    spec = json.loads(Path(args.spec).read_text())
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    report = {}
    for role, mon in spec["monitors"].items():
        size = tuple(mon["size"])
        src = Path(mon["fallback"])
        with open_for(src, size) as im:
            for i, (layout, cards) in enumerate(mon["layouts"].items()):
                img, rep = compose(im, size, cards, spec, (0.5, 0.5), 1000 + i)
                img.save(out / f"{role}-{layout}.png", "PNG", compress_level=6)
                report[f"{role}-{layout}"] = rep
    (out / "quote").write_text(
        format_quote(spec["quote"]["fallback"], spec["quote"]["columns"], spec["quote"]["lines"],
                     spec["palette"]["subtext"])
    )
    (out / "report.json").write_text(json.dumps(report, indent=1))
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="lockscreen-render")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("prepare")
    p.add_argument("--spec", required=True)
    p.add_argument("--cache", required=True)
    p.add_argument("--seed", type=int, default=None)
    f = sub.add_parser("fallback")
    f.add_argument("--spec", required=True)
    f.add_argument("--out", required=True)
    args = ap.parse_args(argv)
    return cmd_prepare(args) if args.cmd == "prepare" else cmd_fallback(args)


if __name__ == "__main__":
    sys.exit(main())
