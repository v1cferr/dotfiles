"""The arithmetic the conclusions rest on, against hand-computed fixtures (run at build time)."""
import unittest

import metrics
import report

FDINFO = """drm-driver:\txe
drm-client-id:\t7
drm-cycles-rcs:\t300
drm-total-cycles-rcs:\t1000

drm-driver:\txe
drm-client-id:\t7
drm-cycles-rcs:\t300
drm-total-cycles-rcs:\t1000

drm-driver:\txe
drm-client-id:\t9
drm-cycles-rcs:\t100
drm-total-cycles-rcs:\t1200
"""


def snap(t, ticks, rc6, frames, uj):
    return {"t": t, "frames": {"DP-1": frames}, "rc6_ms": rc6, "gpu_card_uj": uj,
            "cores": {"cpu0": (t * 10, t * 100), "cpu1": (t * 50, t * 100)},
            "procs": {"hyprland": {"ticks": ticks, "rss": 2048, "pss": None, "gpu": None}}}


class Metrics(unittest.TestCase):
    def test_fdinfo_counts_each_client_once(self):
        # client 7 has two fds (same counters), client 9 one: 300 + 100 busy, the newest total
        self.assertEqual(metrics.parse_fdinfo(FDINFO), (400, 1200))

    def test_fdinfo_without_xe_is_unknown(self):
        self.assertIsNone(metrics.parse_fdinfo("pos:\t0\nflags:\t02\n"))

    def test_rates(self):
        row = metrics.rates(snap(0, 0, 0, 0, 0), snap(10, 50, 7500, 1800, 20e6))
        self.assertAlmostEqual(row["hyprland_cpu_pct"], 100 * 50 / metrics.TICK / 10)
        self.assertAlmostEqual(row["gpu_busy_pct"], 25.0)  # 7.5 s of RC6 in 10 s
        self.assertAlmostEqual(row["fps_DP-1"], 180.0)
        self.assertAlmostEqual(row["gpu_card_w"], 2.0)
        self.assertAlmostEqual(row["cpu_all_pct"], 30.0)  # cores at 10% and 50%
        self.assertAlmostEqual(row["cpu_max_core_pct"], 50.0)
        self.assertEqual(row["hyprland_rss_mib"], 2.0)

    def test_missing_source_stays_missing(self):
        a, b = snap(0, 0, None, 0, None), snap(5, 5, None, 0, None)
        row = metrics.rates(a, b)
        self.assertIsNone(row["gpu_busy_pct"])
        self.assertIsNone(row["gpu_card_w"])


class Report(unittest.TestCase):
    ROWS = [
        {"scenario": "A", "workload": "idle", "invalid": None, "x": 10.0},
        {"scenario": "A", "workload": "idle", "invalid": None, "x": 14.0},
        {"scenario": "B", "workload": "idle", "invalid": None, "x": 6.0},
        {"scenario": "B", "workload": "idle", "invalid": "input during the block", "x": 99.0},
    ]

    def test_aggregate_skips_invalid_blocks(self):
        agg = report.aggregate(self.ROWS)
        mean, sd, n = agg[("A", "idle")]["x"]
        self.assertEqual((mean, n), (12.0, 2))
        self.assertAlmostEqual(sd, 2.8284, places=3)
        self.assertEqual(agg[("B", "idle")]["x"], (6.0, None, 1))

    def test_delta_against_baseline(self):
        agg = report.aggregate(self.ROWS)
        self.assertAlmostEqual(report.delta(agg, "B", "idle", "x"), -50.0)
        self.assertIsNone(report.delta(agg, "B", "idle", "absent"))


if __name__ == "__main__":
    unittest.main()
