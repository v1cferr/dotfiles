"""Phase 2a: the managed block, the write shapes, and a plan that runs nothing."""

from __future__ import annotations

import contextlib
import copy
import io
import json
import os
import stat
import tempfile
import unittest
from pathlib import Path
from typing import Any

import cli
import compare
import plan
import state
from adb import Adb, allowed, allowed_write
from fake import SPEC, FakeAdb, healthy, isolate_overlay, spec_file
from spec import SpecError, parse

MANAGED = {
    "settings": {"system": {"screen_off_timeout": "60000"}},
    "packagesDisabled": ["org.example.notes", "com.example.gone"],
    "permissionsRevoked": {"org.example.notes": ["android.permission.RECORD_AUDIO",
                                                 "android.permission.READ_SMS"]},
}
TIMEOUT = ("shell", "settings", "get", "system", "screen_off_timeout")


def spec_with(managed: Any = MANAGED) -> dict[str, Any]:
    data = copy.deepcopy(SPEC)
    data["managed"] = copy.deepcopy(managed)
    return data


def checks(answers: dict[tuple[str, ...], Any], data: dict[str, Any]) -> dict[str, plan.Check]:
    fake = FakeAdb(answers)
    spec = parse(data)
    out = {c.op.target: c for c in plan.checks(spec, state.observe(Adb(fake), spec))}
    writes = [c for c in fake.calls if allowed_write(c)]
    assert writes == [], writes  # planning never writes
    return out


class Checks(unittest.TestCase):
    def test_drift_becomes_reversible_operations(self) -> None:
        cs = checks({**healthy(), TIMEOUT: "30000\n"}, spec_with())
        t = cs["system.screen_off_timeout"]
        self.assertEqual((t.state, t.op.before, t.op.after), ("change", "30000", "60000"))
        self.assertEqual(t.op.undo(), ["shell", "settings", "put", "system", "screen_off_timeout", "30000"])
        self.assertFalse(t.op.sensitive)
        notes = cs["org.example.notes"]
        self.assertEqual(notes.op.argv(), ["shell", "pm", "disable-user", "--user", "0", "org.example.notes"])
        self.assertEqual(notes.op.undo()[:3], ["shell", "pm", "enable"])
        self.assertEqual(cs["com.example.gone"].state, "in-sync")
        audio = cs["org.example.notes android.permission.RECORD_AUDIO"]
        self.assertEqual(audio.state, "change")
        self.assertTrue(audio.op.sensitive)
        self.assertEqual(cs["org.example.notes android.permission.READ_SMS"].state, "in-sync")

    def test_in_sync_plans_nothing(self) -> None:
        answers = {**healthy(), TIMEOUT: "60000\n",
                   ("shell", "pm", "list", "packages", "-d"): "package:org.example.notes\n",
                   ("shell", "dumpsys", "package", "org.example.notes"): ""}
        self.assertTrue(all(c.state == "in-sync" for c in checks(answers, spec_with()).values()))

    def test_unset_before_is_undone_by_delete(self) -> None:
        t = checks({**healthy(), TIMEOUT: "null\n"}, spec_with())["system.screen_off_timeout"]
        self.assertEqual(t.op.undo(), ["shell", "settings", "delete", "system", "screen_off_timeout"])

    def test_no_evidence_or_no_exact_undo_blocks(self) -> None:
        unread = checks(healthy(), spec_with())["system.screen_off_timeout"]
        self.assertEqual((unread.state, unread.note), ("blocked", "the read failed"))
        free_text = checks({**healthy(), TIMEOUT: "some free text\n"}, spec_with())
        self.assertEqual(free_text["system.screen_off_timeout"].state, "blocked")
        answers = healthy()
        del answers[("shell", "dumpsys", "package", "org.example.notes")]
        self.assertEqual(checks({**answers, TIMEOUT: "1\n"}, spec_with())[
            "org.example.notes android.permission.RECORD_AUDIO"].state, "blocked")


class Validation(unittest.TestCase):
    def test_refused_declarations(self) -> None:
        bad: list[Any] = [
            {"settings": {"global": {"auto_time": "1"}}},  # already audited
            {"settings": {"global": {"adb_enabled": "0"}}},  # manual
            {"settings": {"global": {"x": "two words"}}},
            {"settings": {"vendor": {"x": "1"}}},
            {"packagesDisabled": ["com.google.android.gms"]},  # the protected floor
            {"packagesDisabled": ["com.android.vending"]},  # mustBeEnabled
            {"permissionsRevoked": {"org.example.notes": ["RECORD_AUDIO"]}},
            {"uninstall": ["org.example.notes"]},
        ]
        for managed in bad:
            with self.assertRaises(SpecError, msg=json.dumps(managed)):
                parse(spec_with(managed))

    def test_write_shapes(self) -> None:
        good = [["shell", "settings", "put", "global", "auto_time", "1"],
                ["shell", "settings", "delete", "secure", "x"],
                ["shell", "pm", "disable-user", "--user", "0", "com.a.b"],
                ["shell", "pm", "grant", "com.a.b", "android.permission.CAMERA"]]
        bad = [["shell", "settings", "put", "global", "x", "1; reboot"],
               ["shell", "pm", "uninstall", "--user", "0", "com.a.b"],
               ["shell", "pm", "disable-user", "--user", "10", "com.a.b"],
               ["shell", "pm", "clear", "com.a.b"], ["shell", "reboot"]]
        for argv in good:
            self.assertTrue(allowed_write(argv), argv)
            self.assertFalse(allowed(argv), argv)  # the read path can never reach a write
        for argv in bad:
            self.assertFalse(allowed_write(argv), argv)

    def test_digest_follows_the_declaration(self) -> None:
        self.assertEqual(parse(spec_with()).digest, parse(spec_with()).digest)
        self.assertNotEqual(parse(spec_with()).digest, parse(SPEC).digest)


class Command(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        isolate_overlay(self.tmp)
        os.environ["XDG_STATE_HOME"] = str(self.tmp / "state")
        self.spec = spec_file(self.tmp, spec_with())

    def run_cli(self, answers: dict[tuple[str, ...], Any], *argv: str) -> tuple[int, str]:
        with contextlib.redirect_stdout(io.StringIO()) as out, contextlib.redirect_stderr(io.StringIO()):
            code = cli.main(["--spec", self.spec, *argv], FakeAdb(answers))
        return code, out.getvalue()

    def test_plan_saves_owner_only_outside_the_repo(self) -> None:
        code, out = self.run_cli({**healthy(), TIMEOUT: "30000\n"}, "plan")
        self.assertEqual(code, 1)
        (saved,) = (self.tmp / "state" / "android-iac" / "plans").iterdir()
        self.assertEqual(stat.S_IMODE(saved.stat().st_mode), 0o600)
        doc = json.loads(saved.read_text())
        self.assertEqual(doc["specDigest"], parse(spec_with()).digest)
        self.assertEqual(len(doc["ops"]), 3)
        self.assertIn("nothing was run", out)

    def test_blocked_saves_nothing(self) -> None:
        code, out = self.run_cli(healthy(), "plan")
        self.assertEqual(code, 3)
        self.assertFalse((self.tmp / "state").exists())
        self.assertIn("would be a guess", out)

    def test_diff_shows_managed_drift(self) -> None:
        spec = parse(spec_with())
        observed = state.observe(Adb(FakeAdb({**healthy(), TIMEOUT: "30000\n"})), spec)
        f = {x.check: x for x in compare.findings(spec, observed)}["managed system.screen_off_timeout"]
        self.assertEqual(f.status, compare.Status.DRIFT)
        self.assertIn("android-iac plan", f.note)

    def test_diff_shows_an_in_sync_package_as_it_reads(self) -> None:
        spec = parse(spec_with({"packagesDisabled": ["org.example.notes", "com.example.gone"]}))
        disabled = ("shell", "pm", "list", "packages", "-d")
        observed = state.observe(Adb(FakeAdb({**healthy(), disabled: "package:org.example.notes\n"})), spec)
        f = {x.check: x for x in compare.findings(spec, observed)}
        self.assertEqual((f["managed org.example.notes"].status, f["managed org.example.notes"].observed),
                         (compare.Status.IN_SYNC, "disabled"))
        self.assertEqual((f["managed com.example.gone"].status, f["managed com.example.gone"].observed),
                         (compare.Status.IN_SYNC, "absent"))


if __name__ == "__main__":
    unittest.main()
