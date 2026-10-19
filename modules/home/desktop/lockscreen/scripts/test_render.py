"""The renderer and the shell pieces against fixtures: geometry, selection, glass, cache, text, labels.

Run by `nix build .#checks.x86_64-linux.lockscreen`; every image here is synthetic, so no binary
enters git. LOCKSCREEN_SPEC points at the spec Nix generated, the real one the desktop uses.
"""

import json
import os
import random
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

import render as R

HERE = Path(__file__).parent
SPEC = json.loads(Path(os.environ["LOCKSCREEN_SPEC"]).read_text())
QS_THEME = os.environ.get("LOCKSCREEN_THEME_QML")
HYPR_GLASS = os.environ.get("LOCKSCREEN_GLASS_LUA")


def photo(path: Path, size: tuple, bright: bool = False, seed: int = 1) -> Path:
    """A deterministic 'space photo': dark sky, stars, and (bright) a white nebula core."""
    rng = random.Random(seed)
    img = Image.new("RGB", size, (10, 10, 18))
    d = ImageDraw.Draw(img)
    for _ in range(400):
        x, y = rng.randrange(size[0]), rng.randrange(size[1])
        d.point((x, y), fill=(255, 255, 255))
    if bright:
        w, h = size
        d.ellipse((w * 0.1, h * 0.1, w * 0.9, h * 0.9), fill=(235, 225, 215))
    img.save(path)
    return path


def stripes(size: tuple) -> Image.Image:
    """The theme note's test backdrop: bright colored stripes, white included."""
    img = Image.new("RGB", size)
    d = ImageDraw.Draw(img)
    colors = [(255, 255, 255), (255, 60, 60), (60, 255, 60), (60, 60, 255), (0, 0, 0)]
    for i in range(0, size[0], 40):
        d.rectangle((i, 0, i + 39, size[1]), fill=colors[(i // 40) % len(colors)])
    return img


class Geometry(unittest.TestCase):
    def test_every_layout_fits_its_declared_screen(self):
        for role, mon in SPEC["monitors"].items():
            for layout, cards in mon["layouts"].items():
                self.assertEqual(R.check_layout(cards, tuple(mon["size"])), [], f"{role}/{layout}")

    def test_card_rect_is_centered(self):
        card = {"id": "c", "center": [0, 0], "size": [100, 50]}
        self.assertEqual(R.card_rect(card, (1000, 500)), (450, 225, 550, 275))

    def test_overflow_and_overlap_are_caught(self):
        a = {"id": "a", "center": [0, 0], "size": [400, 400]}
        b = {"id": "b", "center": [100, 0], "size": [400, 400]}
        problems = R.check_layout([a, b], (300, 300))
        self.assertTrue(any("leaves" in p for p in problems))
        self.assertTrue(any("overlaps" in p for p in problems))

    def test_ambient_is_media_without_its_top_card(self):
        # The labels are static, so a card must never MOVE between the two layouts.
        lay = SPEC["monitors"]["secondary"]["layouts"]
        media = {c["id"]: c for c in lay["media"]}
        for c in lay["ambient"]:
            self.assertEqual(c, media[c["id"]])

    def test_logical_size_rotates_and_scales(self):
        lg = {"width": 1920, "height": 1080, "transform": 1, "scale": 1}
        self.assertEqual(R.logical_size(lg), (1080, 1920))
        hi = {"width": 3840, "height": 2160, "transform": 0, "scale": 1.5}
        self.assertEqual(R.logical_size(hi), (2560, 1440))


class Selection(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_orientation_grades(self):
        self.assertEqual(R.suits((3840, 2160), (2560, 1440)), 2)
        self.assertEqual(R.suits((2160, 3840), (2560, 1440)), 0)  # portrait never on the wide one
        self.assertEqual(R.suits((2160, 3840), (1080, 1920)), 2)
        self.assertEqual(R.suits((3840, 2160), (1080, 1920)), 1)  # landscape only through a crop
        self.assertEqual(R.suits((1200, 1200), (2560, 1440)), 0)  # 2.1x upscale: refused

    def test_empty_and_missing_pools(self):
        self.assertEqual(R.candidates([str(self.dir / "nope")]), [])
        self.assertIsNone(R.pick(random.Random(1), [], (2560, 1440), set()))

    def test_invalid_files_are_never_picked(self):
        (self.dir / "broken.jpg").write_bytes(b"not an image")
        (self.dir / "notes.txt").write_text("hello")
        (self.dir / "a.json").write_text("{}")
        good = photo(self.dir / "good.png", (2600, 1500))
        files = R.candidates([str(self.dir)])
        self.assertNotIn(self.dir / "a.json", files)
        for seed in range(10):
            self.assertEqual(R.pick(random.Random(seed), files, (2560, 1440), set()), good)

    def test_portrait_preferred_over_cropped_landscape(self):
        tall = photo(self.dir / "tall.png", (1100, 1950))
        photo(self.dir / "wide.png", (3000, 1700))
        files = R.candidates([str(self.dir)])
        for seed in range(10):
            self.assertEqual(R.pick(random.Random(seed), files, (1080, 1920), set()), tall)

    def test_cover_and_focus(self):
        src = Image.new("RGB", (4000, 1000), (0, 0, 0))
        ImageDraw.Draw(src).rectangle((3000, 0, 3999, 999), fill=(255, 255, 255))
        left = R.cover(src, (1080, 1920), (0.0, 0.5))
        right = R.cover(src, (1080, 1920), (1.0, 0.5))
        self.assertEqual(left.size, (1080, 1920))
        self.assertEqual(left.getpixel((540, 960)), (0, 0, 0))
        self.assertEqual(right.getpixel((540, 960)), (255, 255, 255))

    def test_sidecar_focus_is_clamped(self):
        img = photo(self.dir / "p.png", (2600, 1500))
        img.with_suffix(".json").write_text('{"focus": [1.7, -2]}')
        self.assertEqual(R.focus_of(R.sidecar(img)), (1.0, 0.0))
        img.with_suffix(".json").write_text("garbage")
        self.assertEqual(R.focus_of(R.sidecar(img)), (0.5, 0.5))


class Glass(unittest.TestCase):
    def compose(self, src, role="primary", layout="main"):
        mon = SPEC["monitors"][role]
        return R.compose(src, tuple(mon["size"]), mon["layouts"][layout], SPEC, (0.5, 0.5), 7)

    def test_outside_the_cards_the_photo_is_untouched(self):
        src = stripes((2560, 1440))
        out, _ = self.compose(src)
        for xy in [(5, 5), (2550, 1430), (100, 700)]:
            self.assertEqual(out.getpixel(xy), src.getpixel(xy))

    def test_contrast_holds_over_a_bright_core(self):
        with tempfile.TemporaryDirectory() as d:
            src = Image.open(photo(Path(d) / "b.png", (2560, 1440), bright=True))
            _, report = self.compose(src)
        for card in report:
            for key, need in SPEC["contrast"].items():
                self.assertGreaterEqual(card["contrast"][key], need, f"{card['id']} {key}")
            # Over a near-white core the glass must have gone denser than its floor.
            self.assertGreater(card["alpha"], SPEC["glass"]["alphaMin"])

    def test_dark_photo_keeps_the_clearest_glass(self):
        with tempfile.TemporaryDirectory() as d:
            src = Image.open(photo(Path(d) / "k.png", (2560, 1440)))
            _, report = self.compose(src)
        for card in report:
            self.assertEqual(card["alpha"], SPEC["glass"]["alphaMin"], card["id"])

    def test_transmission_matches_the_desktop_measurement(self):
        # theme.md measured HyprGlass plus a 0.70 surface over stripes at 0.109: the photo must
        # still show through (glass, not a panel) and stay within reach of that material.
        src = stripes((2560, 1440))
        out, report = self.compose(src)
        x0, t, r, b = report[0]["rect"]
        inner = (x0 + 40, t + 40, r - 40, b - 40)

        def spread(img):
            c = img.crop(inner)
            px = c.get_flattened_data() if hasattr(c, "get_flattened_data") else c.getdata()
            lum = [R.luminance(p) for p in px]
            return max(lum) - min(lum)

        transmission = spread(out) / spread(src)
        self.assertGreater(transmission, 0.02)
        self.assertLess(transmission, 0.2)

    def test_deterministic(self):
        src = stripes((2560, 1440))
        a, _ = self.compose(src)
        b, _ = self.compose(src)
        self.assertEqual(a.tobytes(), b.tobytes())

    def test_wcag_math(self):
        self.assertAlmostEqual(R.contrast(R.luminance((255, 255, 255)), R.luminance((0, 0, 0))), 21, 3)
        # The theme note's solid-surface number for `text` over Tokyo Night's bg.
        c = R.contrast(R.luminance(R.rgb("c0caf5")), R.luminance(R.rgb("1a1b26")))
        self.assertAlmostEqual(c, 10.6, 0)


class Profile(unittest.TestCase):
    """The glass numbers mirror the desktop's; a change on one side alone fails here (rule 11)."""

    @unittest.skipUnless(QS_THEME and HYPR_GLASS, "the desktop's sources were not passed in")
    def test_mirrors_theme_qml_and_glass_lua(self):
        qml = Path(QS_THEME).read_text()
        lua = Path(HYPR_GLASS).read_text()
        card = re.search(r'colSurfaceCard: theme\.glassBg\(theme\.glassClear \? "(\w\w)" : "(\w\w)"\)', qml)
        edge = re.search(r'colEdge: aa\(pal\.border, "(\w\w)"\)', qml)
        sheen = re.search(r'colSheen: aa\(pal\.text, "(\w\w)"\)', qml)
        clear = re.search(r'\["clear-gradient"\] = \{ tint = "(\w\w)".*?brightness = ([\d.]+)', lua)
        base = re.search(r'or \{ tint = "(\w\w)".*?brightness = ([\d.]+)', lua)
        self.assertTrue(all([card, edge, sheen, clear, base]), "a source changed shape")
        g = SPEC["glass"]
        if g["solid"]:
            return
        clear_profile = g["gradient"]
        qml_alpha = int(card.group(1 if clear_profile else 2), 16) / 255
        tint, bright = (clear if clear_profile else base).groups()
        # The desktop's opacity sits inside the lock's adaptive range.
        self.assertLessEqual(g["alphaMin"], round(qml_alpha, 2) + 0.005)
        self.assertGreaterEqual(g["alphaMax"], round(qml_alpha, 2) - 0.005)
        self.assertAlmostEqual(g["tint"], int(tint, 16) / 255, 2)
        self.assertAlmostEqual(g["brightness"], float(bright), 3)
        self.assertAlmostEqual(SPEC["edge"]["edge"], int(edge.group(1), 16) / 255, 2)
        self.assertAlmostEqual(SPEC["edge"]["sheen"], int(sheen.group(1), 16) / 255, 2)


class Cache(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def key(self, **over):
        args = dict(digest="d", spec=SPEC, role="primary", layout="main", size=(2560, 1440), focus=(0.5, 0.5))
        args.update(over)
        return R.cache_key(**args)

    def test_key_moves_with_every_input(self):
        base = self.key()
        self.assertEqual(base, self.key())
        spec2 = json.loads(json.dumps(SPEC))
        spec2["palette"]["bg"] = "000000"
        spec3 = json.loads(json.dumps(SPEC))
        spec3["glass"]["tint"] = 0.5
        for other in [
            self.key(digest="e"),
            self.key(size=(2560, 1600)),
            self.key(focus=(0.2, 0.5)),
            self.key(spec=spec2),
            self.key(spec=spec3),
        ]:
            self.assertNotEqual(base, other)

    def test_digest_is_content_not_mtime(self):
        f = self.dir / "x.png"
        f.write_bytes(b"one")
        index = {}
        a = R.file_digest(f, index)
        os.utime(f, (1, 1))
        self.assertEqual(a, R.file_digest(f, {}))
        f.write_bytes(b"two")
        self.assertNotEqual(a, R.file_digest(f, index))

    def test_publish_is_atomic_and_leaves_no_temp(self):
        dest = self.dir / "a.bin"

        def boom(f):
            f.write(b"half")
            raise OSError("disk full")

        with self.assertRaises(OSError):
            R.publish_file(boom, dest)
        self.assertFalse(dest.exists())
        self.assertEqual(list(self.dir.iterdir()), [])
        R.publish_file(lambda f: f.write(b"whole"), dest)
        self.assertEqual(dest.read_bytes(), b"whole")

    def test_corrupt_asset_is_not_valid(self):
        bad = self.dir / "k.png"
        bad.write_bytes(b"\x89PNG broken")
        self.assertFalse(R.valid_png(bad, (10, 10)))
        Image.new("RGB", (10, 10)).save(bad)
        self.assertTrue(R.valid_png(bad, (10, 10)))
        self.assertFalse(R.valid_png(bad, (10, 11)))

    def prepare(self, cache, pools_wide, pools_tall, seed):
        spec = json.loads(json.dumps(SPEC))
        spec["monitors"]["primary"]["pools"] = [str(pools_wide)]
        spec["monitors"]["secondary"]["pools"] = [str(pools_tall)]
        spec["quotesFile"] = str(self.dir / "quotes.json")
        sp = self.dir / "spec.json"
        sp.write_text(json.dumps(spec))
        return R.main(["prepare", "--spec", str(sp), "--cache", str(cache), "--seed", str(seed)])

    def test_prepare_end_to_end_hit_and_collect(self):
        wide, tall, cache = self.dir / "w", self.dir / "t", self.dir / "cache"
        wide.mkdir()
        tall.mkdir()
        photo(wide / "a.png", (2600, 1480))
        photo(tall / "b.png", (1100, 1960))
        self.assertEqual(self.prepare(cache, wide, tall, 1), 0)
        ready = cache / "ready"
        names = sorted(p.name for p in ready.iterdir())
        self.assertEqual(
            names,
            ["manifest.json", "primary-main.png", "quote", "secondary-ambient.png", "secondary-media.png"],
        )
        first = {p.name: p.resolve() for p in ready.iterdir() if p.suffix == ".png"}
        mtimes = {n: p.stat().st_mtime_ns for n, p in first.items()}
        # Same photos, same spec: every image is a cache hit, rewritten by nobody.
        self.assertEqual(self.prepare(cache, wide, tall, 2), 0)
        for n, p in first.items():
            self.assertEqual((ready / n).resolve(), p)
            self.assertEqual(p.stat().st_mtime_ns, mtimes[n])
        # A session showing the first set keeps its images through any number of new sets.
        session = cache / "session"
        os.symlink(first["primary-main.png"], session / "primary")
        for i, color in enumerate([(200, 0, 0), (0, 200, 0), (0, 0, 200), (90, 90, 0), (0, 90, 90)]):
            Image.new("RGB", (2600, 1480), color).save(wide / "a.png")
            self.assertEqual(self.prepare(cache, wide, tall, 3 + i), 0)
        self.assertTrue(first["primary-main.png"].exists())
        self.assertLessEqual(len([s for s in (cache / "sets").iterdir()]), R.KEEP_SETS + 1)
        assets = list((cache / "assets").glob("*.png"))
        self.assertLessEqual(len(assets), (R.KEEP_SETS + 1) * 3)

    def test_prepare_with_empty_pools_publishes_no_images(self):
        wide, tall, cache = self.dir / "w", self.dir / "t", self.dir / "cache"
        self.assertEqual(self.prepare(cache, wide, tall, 1), 0)
        self.assertEqual(sorted(p.name for p in (cache / "ready").iterdir()), ["manifest.json", "quote"])


class Quotes(unittest.TestCase):
    def test_wrap_fits_and_refuses(self):
        lines = R.wrap("um dois três quatro cinco seis sete", 12, 4)
        self.assertEqual(lines, ["um dois três", "quatro cinco", "seis sete"])
        self.assertIsNone(R.wrap("palavra " * 40, 10, 4))
        self.assertIsNone(R.wrap("supercalifragilistic", 10, 4))

    def test_wide_characters_take_two_columns(self):
        self.assertEqual(R.columns("日本"), 4)
        self.assertEqual(R.columns("ação"), 4)

    def test_markup_is_escaped_and_authors_only_when_real(self):
        out = R.format_quote({"q": "a < b & c", "a": "Ada"}, 40, 4, "a9b1d6")
        self.assertIn("a &lt; b &amp; c", out)
        self.assertIn("Ada", out)
        anon = R.format_quote({"q": "sem autor", "a": "Unknown"}, 40, 4, "a9b1d6")
        self.assertNotIn("Unknown", anon)
        self.assertIsNone(R.format_quote({"q": ""}, 40, 4, "x"))
        self.assertIsNone(R.format_quote("nonsense", 40, 4, "x"))

    def test_choose_falls_back(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "q.json"
            p.write_text("{broken")
            out = R.choose_quote(p, random.Random(1), SPEC)
            self.assertIn(SPEC["quote"]["fallback"]["a"], out)
            p.write_text(json.dumps([{"q": "x " * 300, "a": "Long"}, {"q": "Curta.", "a": "Real"}]))
            out = R.choose_quote(p, random.Random(1), SPEC)
            self.assertIn("Curta.", out)

    def test_quote_fits_its_card(self):
        q = SPEC["quote"]
        out = R.choose_quote(Path("/nonexistent"), random.Random(1), SPEC)
        text_lines = re.sub(r"<[^>]+>", "", out).split("\n")
        self.assertLessEqual(len(text_lines), q["lines"] + 1)
        self.assertTrue(all(R.columns(x) <= q["columns"] for x in text_lines))


class Labels(unittest.TestCase):
    """label.sh with the same environment Nix gives it, against files in a scratch cache."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.cache = Path(self.tmp.name)
        (self.cache / "session").mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def run_label(self, mode, primary="__none__"):
        env = dict(
            os.environ,
            LOCK_CACHE=str(self.cache),
            LOCK_PRIMARY=primary,
            LOCK_WEATHER_MAX_AGE="43200",
            LOCK_COL_SUBTEXT="a9b1d6",
            LOCK_COL_TEXT="c0caf5",
            LOCK_COL_BG="1a1b26",
            LOCK_TXT_NO_WEATHER="NOWEATHER",
            LOCK_TXT_NO_MEDIA="NOMEDIA",
            LOCK_TXT_HINT="HINT",
        )
        return subprocess.run(
            ["bash", "-euo", "pipefail", str(HERE / "label.sh"), mode],
            env=env, capture_output=True, text=True, check=True,
        ).stdout

    def test_clock_format(self):
        self.assertRegex(self.run_label("clock"), r"^\d\d:\d\d:\d\d$")

    def test_weather_fresh_stale_missing(self):
        import time

        now = int(time.time())
        w = self.cache / "weather"
        self.assertIn("NOWEATHER", self.run_label("weather"))
        w.write_text(f"{now + 600}\n{now - 3600}\n<b>21°C</b>")
        self.assertEqual(self.run_label("weather"), "<b>21°C</b>")
        w.write_text(f"{now - 1}\n{now - 3600}\n<b>21°C</b>")  # the hour it was for is over
        self.assertIn("NOWEATHER", self.run_label("weather"))
        w.write_text(f"{now + 600}\n{now - 50000}\n<b>21°C</b>")  # a forecast over 12 h old
        self.assertIn("NOWEATHER", self.run_label("weather"))
        w.write_text("garbage")
        self.assertIn("NOWEATHER", self.run_label("weather"))

    def test_media_only_in_its_layout_and_only_from_a_live_bridge(self):
        s = self.cache / "session"
        (s / "layout").write_text("ambient")
        (s / "media").write_text(f"{os.getpid()}\nTRACK")
        self.assertEqual(self.run_label("media"), "")
        (s / "layout").write_text("media")
        self.assertEqual(self.run_label("media"), "TRACK")
        (s / "media").write_text("999999999\nTRACK")  # a dead writer: possibly stale
        self.assertIn("NOMEDIA", self.run_label("media"))
        (s / "media").unlink()
        self.assertIn("NOMEDIA", self.run_label("media"))

    def test_quote_and_missing_quote(self):
        self.assertEqual(self.run_label("quote"), "")
        (self.cache / "session" / "quote").write_text("<i>q</i>\nautor\n")
        self.assertEqual(self.run_label("quote"), "<i>q</i>\nautor")

    def test_hint_shows_only_without_the_primary(self):
        self.assertIn("HINT", self.run_label("hint", primary="__no_such_connector__"))


class Bridge(unittest.TestCase):
    """media-bridge.sh's fit(): cut by columns before escaping, never a broken entity."""

    def fit(self, text, cols):
        script = (
            "shopt -u patsub_replacement; "
            f"source <(sed -n '/^width_of()/,/^}}/p;/^fit()/,/^}}/p' {HERE / 'media-bridge.sh'}); "
            'fit "$1" "$2"'
        )
        return subprocess.run(
            ["bash", "-c", script, "_", text, str(cols)],
            env=dict(os.environ, LC_ALL="C.UTF-8"), capture_output=True, text=True, check=True,
        ).stdout

    def test_escapes(self):
        self.assertEqual(self.fit("A & <B>", 20), "A &amp; &lt;B&gt;")

    def test_cuts_with_ellipsis_by_columns(self):
        self.assertEqual(self.fit("abcdefghijkl", 6), "abcde…")
        self.assertEqual(self.fit("日本語のタイトル", 6), "日本…")
        self.assertEqual(self.fit("short", 6), "short")

    def test_never_splits_an_entity(self):
        out = self.fit("&&&&&&&&&&", 4)
        self.assertEqual(out, "&amp;&amp;&amp;…")

    def test_control_characters_are_dropped(self):
        self.assertEqual(self.fit("a\tb\nc", 10), "abc")


if __name__ == "__main__":
    unittest.main()
