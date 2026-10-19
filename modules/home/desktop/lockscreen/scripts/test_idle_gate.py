"""The idle gate's decision against fixtures: only fullscreen video that is playing holds the lock."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

GATE = Path(__file__).with_name("idle-gate.sh")


def decide(fullscreen: str, players: str) -> str:
    with tempfile.TemporaryDirectory() as d:
        Path(d, "fullscreen").write_text(fullscreen)
        Path(d, "players").write_text(players)
        env = dict(os.environ, LOCKGATE_FIXTURES=d)
        out = subprocess.run(
            ["bash", "-euo", "pipefail", str(GATE), "--decide"],
            env=env,
            capture_output=True,
            text=True,
            check=True,
        )
        return out.stdout.strip()


class IdleGate(unittest.TestCase):
    def test_no_players_locks(self):
        self.assertEqual(decide("", ""), "lock")

    def test_audio_alone_locks(self):
        # Spotify playing with nothing fullscreen: the old policy held this forever.
        self.assertEqual(decide("", "453851 Playing\n"), "lock")

    def test_paused_fullscreen_video_locks(self):
        self.assertEqual(decide("17760\n", "17760 Paused\n"), "lock")

    def test_fullscreen_video_playing_holds(self):
        self.assertEqual(decide("17760\n", "17760 Playing\n"), "hold")

    def test_playing_elsewhere_does_not_borrow_a_fullscreen_window(self):
        # A game fullscreen while music plays: different processes, so no hold.
        self.assertEqual(decide("5555\n", "453851 Playing\n"), "lock")

    def test_pid_match_is_exact(self):
        # 1776 is a prefix of 17760 and must not match it.
        self.assertEqual(decide("17760\n", "1776 Playing\n"), "lock")

    def test_one_of_several(self):
        self.assertEqual(
            decide("100\n17760\n", "453851 Playing\n17760 Playing\n"), "hold"
        )


if __name__ == "__main__":
    unittest.main()
