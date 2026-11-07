"""Phase 2b: `apply --dry-run` rehearses a plan that still fits, refuses one that does not, runs nothing."""

from __future__ import annotations

import contextlib
import io
import json
import os
import stat
import tempfile
import unittest
from pathlib import Path
from typing import Any

import cli
from adb import allowed_write
from fake import FakeAdb, healthy, isolate_overlay, spec_file
from test_plan import TIMEOUT, spec_with


class DryRun(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        isolate_overlay(self.tmp)
        os.environ["XDG_STATE_HOME"] = str(self.tmp / "state")
        self.spec = spec_file(self.tmp, spec_with())
        self.state = self.tmp / "state" / "android-iac"

    def run_cli(self, answers: dict[tuple[str, ...], Any], *argv: str, spec: str = "") -> tuple[int, str]:
        fake = FakeAdb(answers)
        with contextlib.redirect_stdout(io.StringIO()) as out, contextlib.redirect_stderr(io.StringIO()):
            code = cli.main(["--spec", spec or self.spec, *argv], fake)
        self.assertEqual([c for c in fake.calls if allowed_write(c)], [])  # a rehearsal never writes
        return code, out.getvalue()

    def planned(self) -> Path:
        self.assertEqual(self.run_cli({**healthy(), TIMEOUT: "30000\n"}, "plan")[0], 1)
        (saved,) = (self.state / "plans").iterdir()
        return saved

    def test_a_plan_that_still_fits_is_rehearsed(self) -> None:
        saved = self.planned()
        code, out = self.run_cli({**healthy(), TIMEOUT: "30000\n"}, "apply", "--dry-run")
        self.assertEqual(code, 0, out)
        self.assertIn("would run    adb shell settings put system screen_off_timeout 60000", out)
        self.assertIn("undo       adb shell settings put system screen_off_timeout 30000", out)
        self.assertIn("nothing was run", out)
        mark = self.state / "rehearsals" / saved.name
        self.assertEqual(stat.S_IMODE(mark.stat().st_mode), 0o600)
        self.assertEqual(len(json.loads(mark.read_text())["planSha256"]), 64)

    def test_a_phone_that_moved_refuses(self) -> None:
        self.planned()
        for value in ("45000\n", "60000\n"):  # changed by hand, or already fixed
            code, out = self.run_cli({**healthy(), TIMEOUT: value}, "apply", "--dry-run")
            self.assertEqual(code, 1, out)
            self.assertIn("not what the phone needs now", out)
        self.assertFalse((self.state / "rehearsals").exists())

    def test_a_changed_declaration_refuses(self) -> None:
        saved = self.planned()
        (self.tmp / "other").mkdir()
        other = spec_with({"settings": {"system": {"screen_off_timeout": "30000"}}})
        code, out = self.run_cli({**healthy(), TIMEOUT: "30000\n"}, "apply", "--dry-run", str(saved),
                                 spec=spec_file(self.tmp / "other", other))
        self.assertEqual(code, 1)
        self.assertIn("the declaration changed", out)

    def test_an_edited_plan_refuses_and_its_commands_are_never_used(self) -> None:
        saved = self.planned()
        doc = json.loads(saved.read_text())
        doc["ops"][0]["argv"] = ["shell", "reboot"]
        saved.write_text(json.dumps(doc))
        code, out = self.run_cli({**healthy(), TIMEOUT: "30000\n"}, "apply", "--dry-run", "--json")
        self.assertEqual(code, 0)  # same operations: the commands are rebuilt, the edit is ignored
        self.assertNotIn("reboot", out)
        doc["ops"][0]["after"] = "1"
        saved.write_text(json.dumps(doc))
        self.assertEqual(self.run_cli({**healthy(), TIMEOUT: "30000\n"}, "apply", "--dry-run")[0], 1)

    def test_no_plan_or_no_dry_run_is_an_error(self) -> None:
        self.assertEqual(self.run_cli({**healthy(), TIMEOUT: "30000\n"}, "apply", "--dry-run")[0], 2)
        self.assertEqual(self.run_cli({**healthy(), TIMEOUT: "30000\n"}, "apply")[0], 2)


if __name__ == "__main__":
    unittest.main()
