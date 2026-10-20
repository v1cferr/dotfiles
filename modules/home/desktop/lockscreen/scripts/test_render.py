"""The renderer, the labels and the bridge against synthetic fixtures and the spec Nix generated
(LOCKSCREEN_SPEC). Run by `nix build .#checks.x86_64-linux.lockscreen`."""

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

    def rects(self, role, layout):
        mon = SPEC["monitors"][role]
        return {c["id"]: R.card_rect(c, tuple(mon["size"])) for c in mon["layouts"][layout]}

    def test_asus_is_editorial_on_one_axis(self):
        cards = SPEC["monitors"]["primary"]["layouts"]["main"]
        self.assertEqual([c["id"] for c in cards], ["column", "quote"])
        self.assertTrue(all(c["material"] == "scrim" for c in cards), "no card on the ASUS")
        for k, (x0, _, x1, _) in self.rects("primary", "main").items():
            self.assertEqual(x0 + x1, 2560, f"{k} is off the vertical axis")

    def test_every_card_is_on_whole_pixels(self):
        for role, mon in SPEC["monitors"].items():
            for cards in mon["layouts"].values():
                for c in cards:
                    w, h = mon["size"]
                    for v in (w / 2 + c["center"][0] - c["size"][0] / 2, h / 2 + c["center"][1] - c["size"][1] / 2):
                        self.assertEqual(v, int(v), c["id"])

    def test_lg_bento_cards_on_the_grid(self):
        med, amb = self.rects("secondary", "media"), self.rects("secondary", "ambient")
        self.assertEqual(med["energy"], (72, 184, 1008, 512))
        self.assertEqual(med["claude"], (72, 536, 1008, 864))
        self.assertEqual(med["system"], (72, 888, 528, 1192))
        self.assertEqual(med["procs"], (552, 888, 1008, 1192))
        self.assertEqual(med["weather"], (72, 1216, 528, 1456))
        self.assertEqual(med["media"], (552, 1216, 1008, 1456))
        for r in med.values():  # every edge on the 8 px grid
            self.assertTrue(all(v % 8 == 0 for v in r), r)
        # Ambient: no media card, the weather takes the row, nothing else moves.
        self.assertNotIn("media", amb)
        self.assertEqual(amb["weather"], (72, 1216, 1008, 1456))
        for k in ("energy", "claude", "system", "procs"):
            self.assertEqual(amb[k], med[k])

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
    def compose(self, src, role="secondary", layout="ambient"):
        mon = SPEC["monitors"][role]
        return R.compose(src, tuple(mon["size"]), mon["layouts"][layout], SPEC, (0.5, 0.5), 7)

    def test_outside_the_cards_the_photo_is_untouched(self):
        src = stripes((2560, 1440))
        out, _ = self.compose(src, "primary", "main")
        for xy in [(5, 5), (2550, 1430), (100, 700)]:
            self.assertEqual(out.getpixel(xy), src.getpixel(xy))

    @staticmethod
    def floor(card):
        """The material's own floor: the scrim's or the glass's."""
        return (SPEC["scrim"] if card.get("material") == "scrim" else SPEC["glass"])["alphaMin"]

    def every_layout(self, bright):
        with tempfile.TemporaryDirectory() as d:
            for role, mon in SPEC["monitors"].items():
                src = Image.open(photo(Path(d) / f"{role}.png", tuple(mon["size"]), bright=bright))
                for layout, cards in mon["layouts"].items():
                    yield cards, self.compose(src, role, layout)[1]

    def test_contrast_holds_over_a_bright_core(self):
        for cards, report in self.every_layout(True):
            for card, rep in zip(cards, report):
                for key, need in (card.get("contrast") or SPEC["contrast"]).items():
                    self.assertGreaterEqual(rep["contrast"][key], need, f"{rep['id']} {key}")
                # Over a near-white core the material must have gone denser than its floor.
                self.assertGreater(rep["alpha"], self.floor(card))

    def test_dark_photo_keeps_each_cards_baseline(self):
        for cards, report in self.every_layout(False):
            for card, rep in zip(cards, report):
                self.assertEqual(rep["alpha"], max(card.get("alpha", 0), self.floor(card)), rep["id"])

    def test_the_rim_is_lit_at_the_top_and_not_at_the_foot(self):
        src = Image.new("RGB", (1080, 1920), (20, 20, 30))
        out, report = self.compose(src)
        x0, t, r, b = report[0]["rect"]
        mid = (x0 + r) // 2
        top = R.luminance(out.getpixel((mid, t)))
        foot = R.luminance(out.getpixel((mid, b - 1)))
        self.assertGreater(top, foot)

    def test_the_shadow_darkens_without_blurring_the_photo(self):
        src = stripes((1080, 1920))
        out, report = self.compose(src)
        x0, t, r, b = report[0]["rect"]
        below = (x0 + 40, b + 6)
        self.assertLessEqual(sum(out.getpixel(below)), sum(src.getpixel(below)))
        far = (5, 5)
        self.assertEqual(out.getpixel(far), src.getpixel(far))

    def test_transmission_matches_the_desktop_measurement(self):
        # theme.md measured HyprGlass plus a 0.70 surface over stripes at 0.109: the photo must
        # still show through (glass, not a panel) and stay within reach of that material.
        src = stripes((1080, 1920))
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


class Editorial(unittest.TestCase):
    """The scrim (text straight over the art) and the panel's hairline rules, on synthetic cards."""

    SCRIM = {"id": "s", "center": [0, 0], "size": [1000, 400], "radius": 0, "material": "scrim"}

    def test_the_scrim_reaches_aa_over_a_bright_photo(self):
        with tempfile.TemporaryDirectory() as d:
            src = Image.open(photo(Path(d) / "b.png", (2560, 1440), bright=True))
            _, report = R.compose(src, (2560, 1440), [self.SCRIM], SPEC, (0.5, 0.5), 3)
        for key, need in SPEC["contrast"].items():
            self.assertGreaterEqual(report[0]["contrast"][key], need, key)
        self.assertGreater(report[0]["alpha"], SPEC["scrim"]["alphaMin"])

    def test_the_scrim_darkens_without_blurring_and_fades_out(self):
        src = stripes((2560, 1440))
        out, _ = R.compose(src, (2560, 1440), [self.SCRIM], SPEC, (0.5, 0.5), 3)
        # The stripes stay sharp under it: darker, never smeared into one gray.
        a, b = out.getpixel((1280 - 20, 720)), out.getpixel((1280 + 20, 720))
        self.assertNotEqual(a, b)
        self.assertLess(sum(out.getpixel((1282, 720))), sum(src.getpixel((1282, 720))) + 3)
        # Past the feather the photo is untouched.
        self.assertEqual(out.getpixel((5, 5)), src.getpixel((5, 5)))


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
        spec["quotesSeen"] = str(self.dir / "state" / "seen.json")
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

    @staticmethod
    def entry(i, kind="stoic", **kw):
        return {"id": f"q{i}", "kind": kind, "text": f"Frase {i}.", "lang": "pt", "author": f"Autor {i}", **kw}

    def test_markup_is_escaped_with_original_and_credit(self):
        q = self.entry(1, kind="computing", text="a < b & c", original="x & y", lang="en", source="Notes",
                       year="1843")
        out = R.format_quote(q, SPEC)
        self.assertIn("a &lt; b &amp; c", out)
        self.assertIn("x &amp; y", out)
        self.assertIn("Autor 1 · Notes · 1843", out)

    def test_greek_gets_a_face_that_has_it(self):
        q = self.entry(1, original="ὁ κόσμος ἀλλοίωσις", lang="grc")
        self.assertIn(f'font_family="{SPEC["quote"]["originalFonts"]["grc"]}"', R.format_quote(q, SPEC))

    def test_portuguese_shows_no_original_and_invalid_is_none(self):
        self.assertNotIn("ORIG", R.format_quote(self.entry(1, original="ORIG"), SPEC))
        self.assertIsNone(R.format_quote({"text": "sem id"}, SPEC))
        self.assertIsNone(R.format_quote(self.entry(1, kind="spam"), SPEC))
        self.assertIsNone(R.format_quote("nonsense", SPEC))

    def test_haiku_keeps_its_three_lines_without_quotation_marks(self):
        q = self.entry(1, kind="haiku", text="um\ndois\ntrês", original="古池や蛙飛び込む水の音", lang="ja")
        out = R.format_quote(q, SPEC)
        self.assertTrue(out.startswith("<i>um\ndois\ntrês</i>"))
        self.assertNotIn("“", out)

    def choose(self, items, haiku_ok, seen, seed):
        with tempfile.TemporaryDirectory() as d:
            spec = json.loads(json.dumps(SPEC))
            spec["quotesFile"] = str(Path(d) / "q.json")
            Path(spec["quotesFile"]).write_text(json.dumps(items))
            return R.choose_quote(spec, random.Random(seed), haiku_ok, seen)

    def test_no_repeat_until_everything_was_shown(self):
        with tempfile.TemporaryDirectory() as d:
            seen = Path(d) / "s" / "seen.json"
            items = [self.entry(i) for i in range(3)]
            shown = [self.choose(items, False, seen, i) for i in range(3)]
            self.assertEqual(len(set(shown)), 3)
            again = self.choose(items, False, seen, 9)  # all seen: the history resets...
            self.assertNotEqual(again, shown[-1])  # ...but never repeats the last one
            self.assertEqual(len(json.loads(seen.read_text())), 2)

    def test_haiku_only_beside_a_print(self):
        items = [self.entry(1, kind="haiku", text="a\nb\nc", lang="ja", original="あ"), self.entry(2)]
        for seed in range(20):
            self.assertIn("Frase 2.", self.choose(items, False, None, seed))
        self.assertTrue(any("<i>a\nb\nc</i>" in self.choose(items, True, None, s) for s in range(20)))

    def test_choose_falls_back(self):
        with tempfile.TemporaryDirectory() as d:
            spec = json.loads(json.dumps(SPEC))
            spec["quotesFile"] = str(Path(d) / "q.json")
            Path(spec["quotesFile"]).write_text("{broken")
            out = R.choose_quote(spec, random.Random(1), True)
            self.assertIn(SPEC["quote"]["fallback"]["author"], out)

    def test_the_collection_is_valid_and_every_entry_fits(self):
        items = json.loads(Path(SPEC["quotesFile"]).read_text())
        ids = [q.get("id") for q in items]
        self.assertEqual(len(ids), len(set(ids)), "duplicate ids")
        for q in items:
            self.assertTrue(R.valid_quote(q), q.get("id"))
            if q["lang"] == "pt":
                self.assertNotIn("original", q, q["id"])
            if q["kind"] == "haiku":
                self.assertEqual(len(q["text"].split("\n")), 3, q["id"])
            self.assertNotIn("—", q["text"] + q.get("original", ""), q["id"])  # the repo's prose rule
            self.assertIsNotNone(R.format_quote(q, SPEC), f"{q['id']} does not fit the band")


class Labels(unittest.TestCase):
    """label.sh with the same environment Nix gives it, against files in a scratch cache."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.cache = Path(self.tmp.name)
        (self.cache / "session").mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def run_label(self, mode, arg=None, primary="__none__"):
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
            LOCK_TXT_NO_DATA="NODATA",
            LOCK_OBS_MAX_AGE="180",
            LOCK_META_SIZE="13312",
        )
        return subprocess.run(
            ["bash", "-euo", "pipefail", str(HERE / "label.sh"), mode]
            + (arg if isinstance(arg, list) else [arg] if arg else []),
            env=env, capture_output=True, text=True, check=True,
        ).stdout

    def test_clock_format(self):
        # The inlined command, run the way hyprlock runs it: `/bin/sh -c`, which is bash on NixOS.
        cmd = (HERE / "clock.sh").read_text().rstrip("\n").split("\n")[-1]
        for k, v in {"@ACCENT@": "7aa2f7", "@SECONDS@": "Geist Light 44", "@RISE@": "84000"}.items():
            cmd = cmd.replace(k, v)
        self.assertNotIn("@", cmd.replace("Geist Light 44", ""))  # every placeholder filled
        out = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, check=True).stdout
        self.assertRegex(out, r'^<span font_features="tnum">\d\d:\d\d</span>'
                              r'<span font_desc="Geist Light 44" rise="84000" foreground="#7aa2f7"> \d\d</span>$')

    def test_weather_fresh_stale_missing(self):
        import time

        now = int(time.time())
        w = self.cache / "weather"
        self.assertIn("NOWEATHER", self.run_label("weather"))
        w.write_text(f"{now + 600}\n{now - 3600}\n<b>21°C</b>\nNublado\n--\nmáx 26°\n")
        out = self.run_label("weather")
        self.assertTrue(out.startswith("<b>21°C</b>\nNublado\nmáx 26°\n"), out)
        self.assertIn("previsão das", out)
        self.assertEqual(self.run_label("weather", ["now"]), "<b>21°C</b>\nNublado")
        self.assertTrue(self.run_label("weather", ["day"]).startswith("máx 26°\n"))
        self.assertEqual(self.run_label("weather", ["now", "media"]), "")  # another layout: nothing
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

    def test_only_prints_in_its_layout(self):
        self.assertEqual(self.run_label("only", ["media", "CAP"]), "")
        (self.cache / "session" / "layout").write_text("media")
        self.assertEqual(self.run_label("only", ["media", "CAP"]), "CAP")

    def test_quote_and_missing_quote(self):
        self.assertEqual(self.run_label("quote"), "")
        (self.cache / "session" / "quote").write_text("<i>q</i>\nautor\n")
        self.assertEqual(self.run_label("quote"), "<i>q</i>\nautor")

    def test_obs_card_only_from_a_live_and_fresh_writer(self):
        import time

        obs = self.cache / "session" / "obs"
        obs.mkdir()
        self.assertIn("NODATA", self.run_label("obs", "energy"))
        (obs / "energy").write_text(f"{os.getpid()}\n{int(time.time())}\n<b>53 W</b>\n")
        self.assertEqual(self.run_label("obs", "energy"), "<b>53 W</b>")
        (obs / "energy").write_text(f"{os.getpid()}\n{int(time.time()) - 600}\n<b>53 W</b>")
        self.assertIn("NODATA", self.run_label("obs", "energy"))  # stale
        (obs / "energy").write_text(f"999999999\n{int(time.time())}\n<b>53 W</b>")
        self.assertIn("NODATA", self.run_label("obs", "energy"))  # dead writer

    def test_hint_shows_only_without_the_primary(self):
        self.assertIn("HINT", self.run_label("hint", primary="__no_such_connector__"))


class Logo(unittest.TestCase):
    """The logo is decoration: centered by its INK, never distorted, and never a reason not to render."""

    SVG = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">'
        '<rect x="10" y="5" width="60" height="30" fill="#000"/></svg>'
    )

    def test_missing_logo_is_none(self):
        self.assertIsNone(R.load_logo({"logo": {"path": "/nonexistent.svg"}}))
        self.assertIsNone(R.load_logo({}))

    def test_cropped_to_ink_scaled_without_distortion_and_centered(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "l.svg"
            p.write_text(self.SVG)
            mask = R.load_logo({"logo": {"path": str(p)}})
        self.assertIsNotNone(mask)
        self.assertAlmostEqual(mask.width / mask.height, 2.0, delta=0.05)  # the ink, not the viewBox
        base = Image.new("RGB", (400, 200))
        card = {"center": [0, 0]}
        x0, y0, x1, y1 = R.place_logo(base, mask, card, {"size": 60, "dy": 0}, (255, 255, 255))
        self.assertEqual(x1 - x0, 60)
        self.assertAlmostEqual((x1 - x0) / (y1 - y0), 2.0, delta=0.1)
        self.assertLessEqual(abs((x0 + x1) / 2 - 200), 0.5)
        self.assertLessEqual(abs((y0 + y1) / 2 - 100), 0.5)

    def test_a_broken_svg_renders_without_logo(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "bad.svg"
            p.write_text("<svg><unclosed")
            self.assertIsNone(R.load_logo({"logo": {"path": str(p)}}))


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
