"""The observability adapter against fixtures: a fake power-log, a fake glance-feed cache and a fake
/proc, so every number on the LG card is checked against what its source really said."""

import json
import os
import sqlite3
import sys
import tempfile
import time
import unittest
from pathlib import Path

HERE = Path(__file__).parent


def load(env: dict):
    """observe.py reads its source paths at import: import it fresh against these fixtures."""
    os.environ.update(env)
    sys.modules.pop("observe", None)
    import observe

    return observe


def csv_line(t, profile="balanced", cpu=20.0, gpu=40.0, render=50.0, busy=10.0):
    stamp = time.strftime("%Y-%m-%dT%H:%M:%S-03:00", time.localtime(t))
    return f"{stamp},60,{profile},{cpu},{cpu / 2},{gpu},{gpu / 2},{cpu + gpu},,{render},99,{busy},40,40,50\n"


HEADER = ("time,interval_s,profile,cpu_package_w,cpu_cores_w,gpu_board_w,gpu_chip_w,measured_w,wall_w,"
          "gpu_render_idle_pct,gpu_media_idle_pct,cpu_busy_pct,cpu_c,gpu_c,nvme_c\n")


class Energy(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.o = load({"OBSERVE_POWER_DIR": str(self.dir)})
        self.now = time.time()

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, lines):
        (self.dir / time.strftime("%Y-%m.csv")).write_text(HEADER + "".join(lines))

    def test_no_logger_is_missing_never_zero(self):
        e = self.o.energy(self.now)
        self.assertEqual(e["status"], "missing")
        self.assertNotIn("measured_w", e)

    def test_units_sources_and_label(self):
        self.write([csv_line(self.now - 30, cpu=16.0, gpu=37.0)])
        e = self.o.energy(self.now)
        self.assertEqual((e["status"], e["unit"], e["source"]), ("ok", "W", "power-log"))
        self.assertEqual(e["label"], "CPU + GPU measured")  # never "the PC's power"
        self.assertEqual((e["cpu_w"], e["gpu_w"], e["measured_w"]), (16.0, 37.0, 53.0))

    def test_a_missing_minute_is_a_hole(self):
        self.write([csv_line(self.now - 60 * k) for k in (1, 2, 5)])
        h = self.o.energy(self.now)["history"]
        self.assertEqual(len(h), 30)
        self.assertEqual(sum(v is None for v in h), 27)

    def test_stale_logger_says_so(self):
        self.write([csv_line(self.now - 900)])
        self.assertEqual(self.o.energy(self.now)["status"], "stale")

    def test_baseline_only_from_comparable_idle(self):
        idle = [csv_line(self.now - 3600 - 60 * k, "power-saver", 16, 37, render=90, busy=3) for k in range(40)]
        stream = [csv_line(self.now - 7200 - 60 * k, "power-saver", 30, 60, render=20, busy=5) for k in range(60)]
        self.write(sorted(idle + stream))
        b = self.o.energy(self.now)["baseline"]
        self.assertEqual(b["median_w"], 53.0)  # the stream minutes, Eco too, are not idle
        self.assertEqual(b["samples"], 40)

    def test_too_few_idle_samples_give_no_baseline(self):
        self.write([csv_line(self.now - 60 * k, "power-saver", render=90, busy=3) for k in range(5)])
        self.assertIsNone(self.o.energy(self.now)["baseline"])


class Claude(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.db = Path(self.tmp.name) / "glance.db"
        self.o = load({"OBSERVE_GLANCE_DB": str(self.db)})
        self.now = time.time()

    def tearDown(self):
        self.tmp.cleanup()

    def put(self, doc, checked=None, error=None):
        db = sqlite3.connect(self.db)
        db.execute("create table if not exists feed (name text primary key, json text, source text,"
                   " updated_at integer, checked_at integer, error text)")
        db.execute("insert or replace into feed values ('claude_usage', ?, 'anthropic', ?, ?, ?)",
                   (doc if isinstance(doc, str) else json.dumps(doc), int(self.now), int(checked or self.now), error))
        db.commit()
        db.close()

    def test_no_cache_is_missing(self):
        c = self.o.claude(self.now)
        self.assertIn(c["status"], ("missing",))

    def test_values_and_resets(self):
        self.put({"ok": True, "session": {"pct": 24, "resets": self.now + 3000},
                  "weekly": {"pct": 49, "resets": self.now + 90000}, "history": []})
        c = self.o.claude(self.now)
        self.assertEqual((c["status"], c["session"]["pct"], c["weekly"]["pct"]), ("ok", 24, 49))

    def test_a_passed_reset_reads_empty_not_the_old_number(self):
        self.put({"ok": True, "session": {"pct": 88, "resets": self.now - 10}, "weekly": {"pct": 49}})
        self.assertEqual(self.o.claude(self.now)["session"]["pct"], 0)

    def test_missing_fields_are_none_never_zero(self):
        self.put({"ok": True})
        c = self.o.claude(self.now)
        self.assertIsNone(c["session"]["pct"])
        self.assertIsNone(c["weekly"]["pct"])
        self.assertEqual(c["history"]["s"], [None] * 24)

    def test_history_steps_and_starts_at_the_first_sample(self):
        h = [{"ts": self.now - 5 * 3600, "s": 10, "w": 40}, {"ts": self.now - 3600, "s": 30, "w": 45}]
        self.put({"ok": True, "session": {"pct": 30}, "weekly": {"pct": 45}, "history": h})
        s = self.o.claude(self.now)["history"]["s"]
        self.assertEqual(s[:18], [None] * 18)  # before the first sample: holes, not zeros
        self.assertEqual(s[18:22], [10.0] * 4)  # held, not interpolated
        self.assertEqual(s[22:], [30.0, 30.0])

    def test_expired_login_is_an_error_state(self):
        self.put({"ok": False, "error": "no-credentials"})
        c = self.o.claude(self.now)
        self.assertEqual((c["status"], c["error"]), ("error", "no-credentials"))

    def test_stale_and_malformed(self):
        self.put({"ok": True, "session": {"pct": 1}}, checked=self.now - 3600)
        self.assertEqual(self.o.claude(self.now)["status"], "stale")
        self.put("{not json")
        self.assertEqual(self.o.claude(self.now)["error"], "malformed document")


class Procs(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.proc = Path(self.tmp.name)
        self.o = load({"OBSERVE_PROC": str(self.proc)})

    def tearDown(self):
        self.tmp.cleanup()

    def mk(self, pid, comm, ticks, start, rss_pages, cgroup, ppid=1):
        d = self.proc / str(pid)
        d.mkdir(exist_ok=True)
        rest = ["S", str(ppid)] + ["0"] * 9 + [str(ticks), "0"] + ["0"] * 6 + [str(start)]
        (d / "stat").write_text(f"{pid} ({comm}) " + " ".join(rest))
        (d / "statm").write_text(f"100 {rss_pages} 0 0 0 0 0")
        (d / "comm").write_text(comm + "\n")
        (d / "cgroup").write_text(f"0::{cgroup}\n")

    def test_cpu_is_the_delta_and_pid_reuse_is_not_inherited(self):
        hz = self.o.HZ
        self.mk(10, "zen", 1000, 5, 100, "/user.slice/u/app.slice/app-Hyprland-zen\\x2dbeta-9834b158.scope")
        self.mk(11, "Isolated Web Co", 500, 6, 100, "/user.slice/u/app.slice/app-Hyprland-zen\\x2dbeta-9834b158.scope")
        self.mk(20, "old", 99999, 7, 10, "/system.slice/old.service")
        a = {"t": 0.0, "procs": self.o._procs_raw()}
        self.mk(10, "zen", 1000 + hz, 5, 100, "/user.slice/u/app.slice/app-Hyprland-zen\\x2dbeta-9834b158.scope")
        self.mk(11, "Isolated Web Co", 500 + hz // 2, 6, 100,
                "/user.slice/u/app.slice/app-Hyprland-zen\\x2dbeta-9834b158.scope")
        # PID 20 died and a NEW process took the number: a different start time, so no 99999-tick spike.
        self.mk(20, "new", 100000, 999, 10, "/system.slice/new.service")
        b = {"t": 1.0, "procs": self.o._procs_raw()}
        p = self.o.procs(a, b)
        cpu = {i["name"]: i["value"] for i in p["cpu"]}
        self.assertEqual(cpu["zen-beta"], 150.0)  # children grouped into their app, % of ONE core
        self.assertNotIn("new", cpu)
        self.assertNotIn("old", cpu)

    def test_names_never_carry_arguments(self):
        o = self.o
        self.assertEqual(o.group_of("/user.slice/user-1000.slice/session-2.scope", ".quickshell-wra"), "quickshell")
        self.assertEqual(o.group_of("/system.slice/ollama.service", "ollama"), "ollama")
        self.assertEqual(o.group_of("/u/app.slice/app-discord-4007.scope", "Discord"), "discord")
        self.assertEqual(o.group_of("", ".Hyprland-wrapp"), "Hyprland")

    def test_kernel_threads_are_skipped_and_empty_proc_is_empty(self):
        self.mk(30, "kworker/0:1", 50, 1, 0, "/", ppid=2)
        self.assertEqual(self.o._procs_raw(), {})


class Markup(unittest.TestCase):
    PAL = {"text": "c0caf5", "subtext": "a9b1d6", "dim": "565f89", "orange": "ff9e64", "magenta": "bb9af7",
           "blue": "7aa2f7", "teal": "73daca", "sky": "7dcfff"}

    def setUp(self):
        self.o = load({})

    def test_spark_is_zero_based_and_holes_are_dots(self):
        s = self.o.spark([0, 50, 100, None], 100, "fff", "000")
        self.assertIn("▁▅█", s)
        self.assertIn("·", s)

    def test_meter_keeps_its_width_and_says_missing(self):
        import re

        bare = lambda m: re.sub(r"<[^>]+>", "", m)  # noqa: E731
        self.assertEqual(len(bare(self.o.meter(0.25, 20, "a", "b"))), 20)
        self.assertEqual(len(bare(self.o.meter(1.7, 20, "a", "b"))), 20)  # clamped, never wider
        self.assertNotIn('foreground="#a"', self.o.meter(None, 20, "a", "b"))  # no reading: track only

    def test_two_row_chart_has_16_levels_and_dotted_holes(self):
        import re

        rows = [re.sub(r"<[^>]+>", "", r) for r in self.o.spark2([16, 8, 1, None], 16, "a", "b").split("\n")]
        self.assertEqual(rows[0], "█   ")
        self.assertEqual(rows[1], "██▁·")

    def test_process_names_are_escaped_and_aligned(self):
        p = {"cpu": [{"name": "a&b<c>", "value": 5.0}], "mem": []}
        out = self.o.card_apps(p, self.PAL, 70)
        self.assertIn("a&amp;b&lt;c&gt;", out)
        self.assertNotIn("<c>", out)

    def test_missing_energy_and_claude_sections_say_so(self):
        e = self.o.card_energy({"status": "missing", "history": [], "baseline": None}, self.PAL)
        self.assertIn("Sem medições", e)
        c = self.o.cards_claude({"status": "error", "error": "no-credentials"}, self.PAL, time.time())
        self.assertIn("sem login", c["claude-s"])
        self.assertEqual(c["claude-w"], "")

    def test_ring_is_eighths_and_empty_without_a_reading(self):
        r = self.o.RINGS
        self.assertEqual(self.o.ring_glyph(None), r[0])
        self.assertEqual(self.o.ring_glyph(0), r[0])
        self.assertEqual(self.o.ring_glyph(1), r[1])
        self.assertEqual(self.o.ring_glyph(50), r[4])
        self.assertEqual(self.o.ring_glyph(51), r[5])
        self.assertEqual(self.o.ring_glyph(100), r[8])
        self.assertEqual(self.o.ring_glyph(140), r[8])

    def test_body_rows_fit_their_columns(self):
        import re

        bare = lambda m: re.sub(r"<[^>]+>", "", m).replace("&amp;", "&")  # noqa: E731
        p = {"cpu": [{"name": "a-very-long-application-name", "value": 152.0}, {"name": "x", "value": 3.0}]}
        for row in bare(self.o.card_apps(p, self.PAL, 70)).split("\n")[1:]:
            self.assertLessEqual(len(row), 70)
        s = {"cpu_pct": 18.0, "mem": {"used": 9.2 * 1024**3, "total": 32 * 1024**3, "available": 6 * 1024**3},
             "gpu": {"board_w": 44.0, "render_idle_pct": 50.0}}
        for markup in self.o.cards_system(s, {"temps": {"cpu_c": 46}}, self.PAL, 21).values():
            meter_row = bare(markup).split("\n")[2]
            self.assertLessEqual(len(meter_row), 21)


if __name__ == "__main__":
    unittest.main()
