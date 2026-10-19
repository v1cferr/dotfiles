"""lock-launch.sh picks the session's compositor even with a stale WAYLAND_DISPLAY. Only `--print`
runs here, against fake instances and real sockets in a scratch runtime dir: hyprlock never starts."""

import json
import os
import socket
import subprocess
import tempfile
import unittest
from pathlib import Path

LAUNCH = Path(__file__).with_name("lock-launch.sh")


class LockLaunch(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.run_dir = Path(self.tmp.name)
        self.socks = []

    def tearDown(self):
        for s in self.socks:
            s.close()
        self.tmp.cleanup()

    def live(self, name):
        s = socket.socket(socket.AF_UNIX)
        s.bind(str(self.run_dir / name))
        self.socks.append(s)

    def launch(self, instances, wayland_display):
        inst = self.run_dir / "instances.json"
        inst.write_text(json.dumps(instances))
        env = dict(os.environ, XDG_RUNTIME_DIR=str(self.run_dir), LOCKLAUNCH_INSTANCES=str(inst))
        env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
        if wayland_display is None:
            env.pop("WAYLAND_DISPLAY", None)
        else:
            env["WAYLAND_DISPLAY"] = wayland_display
        return subprocess.run(
            ["bash", "-euo", "pipefail", str(LAUNCH), "--print"],
            env=env, capture_output=True, text=True,
        )

    def test_stale_display_is_replaced_by_the_session(self):
        # 18/10/2026: the manager pointed at a socket that no longer existed.
        self.live("wayland-1")
        out = self.launch([{"instance": "a", "time": 100, "pid": 1, "wl_socket": "wayland-1"}], "wayland-9")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual(out.stdout.strip().splitlines()[-1], "wayland-1")
        self.assertIn("not the session's compositor", out.stdout)

    def test_missing_display_is_found(self):
        self.live("wayland-1")
        out = self.launch([{"instance": "a", "time": 100, "pid": 1, "wl_socket": "wayland-1"}], None)
        self.assertEqual(out.stdout.strip().splitlines()[-1], "wayland-1")

    def test_a_nested_test_compositor_never_wins(self):
        # The environment points at a LIVE nested Hyprland: the older session one is still locked.
        self.live("wayland-1")
        self.live("wayland-3")
        insts = [
            {"instance": "nested", "time": 900, "pid": 2, "wl_socket": "wayland-3"},
            {"instance": "session", "time": 100, "pid": 1, "wl_socket": "wayland-1"},
        ]
        out = self.launch(insts, "wayland-3")
        self.assertEqual(out.stdout.strip().splitlines()[-1], "wayland-1")

    def test_an_instance_without_a_socket_is_skipped(self):
        self.live("wayland-2")
        insts = [
            {"instance": "dead", "time": 50, "pid": 1, "wl_socket": "wayland-1"},
            {"instance": "alive", "time": 100, "pid": 2, "wl_socket": "wayland-2"},
        ]
        out = self.launch(insts, "wayland-1")
        self.assertEqual(out.stdout.strip().splitlines()[-1], "wayland-2")

    def test_the_right_display_stays_quietly(self):
        self.live("wayland-1")
        out = self.launch([{"instance": "a", "time": 100, "pid": 1, "wl_socket": "wayland-1"}], "wayland-1")
        self.assertEqual(out.stdout.strip(), "wayland-1")

    def test_no_hyprland_but_a_live_display_is_kept(self):
        self.live("wayland-5")
        out = self.launch([], "wayland-5")
        self.assertEqual(out.stdout.strip(), "wayland-5")

    def test_nothing_alive_fails_the_unit(self):
        out = self.launch([{"instance": "a", "time": 1, "pid": 1, "wl_socket": "wayland-1"}], "wayland-9")
        self.assertEqual(out.returncode, 1)
        self.assertIn("no live Wayland compositor", out.stdout)

    def test_garbage_from_hyprctl_is_survived(self):
        self.live("wayland-1")
        inst = self.run_dir / "instances.json"
        inst.write_text("not json")
        env = dict(os.environ, XDG_RUNTIME_DIR=str(self.run_dir), LOCKLAUNCH_INSTANCES=str(inst),
                   WAYLAND_DISPLAY="wayland-1")
        out = subprocess.run(["bash", "-euo", "pipefail", str(LAUNCH), "--print"],
                             env=env, capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual(out.stdout.strip(), "wayland-1")


if __name__ == "__main__":
    unittest.main()
