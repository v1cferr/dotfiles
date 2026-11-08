"""Phases 2c-2e: apply and rollback on a fake phone whose state changes when it is written to."""

from __future__ import annotations

import contextlib
import datetime as dt
import io
import json
import os
import stat
import tempfile
import unittest
import unittest.mock
from pathlib import Path
from typing import Any, Optional, Sequence

import cli
import plan
from adb import Result, allowed_write
from fake import FakeAdb, healthy, isolate_overlay, spec_file
from test_plan import MANAGED, TIMEOUT, spec_with

DISABLED = ("shell", "pm", "list", "packages", "-d")
NOTES = ("shell", "dumpsys", "package", "org.example.notes")
SETTINGS_ONLY = {"settings": {"system": {"screen_off_timeout": "60000"}}}


class Phone(FakeAdb):
    """Writes land: `settings put/delete` and `pm disable-user/enable` change what later reads see."""

    def __init__(self, answers: dict[tuple[str, ...], Any], refuse: Optional[str] = None) -> None:
        super().__init__(answers)
        self.refuse = refuse  # a target whose write the phone silently ignores

    def __call__(self, args: Sequence[str], input: Optional[str] = None) -> Result:
        a = tuple(args)
        if not allowed_write(a):
            return super().__call__(args, input)
        self.calls.append(a)
        if self.refuse and self.refuse in a:
            return Result(0, "", "")
        if a[1] == "settings":
            self.answers[("shell", "settings", "get", a[3], a[4])] = (a[5] if a[2] == "put" else "null") + "\n"
        elif a[2] in ("disable-user", "enable"):
            pkg = a[-1]
            off = {x for x in str(self.answers[DISABLED]).split() if x != f"package:{pkg}"}
            if a[2] == "disable-user":
                off.add(f"package:{pkg}")
            self.answers[DISABLED] = "\n".join(sorted(off)) + "\n"
        return Result(0, "", "")


class Write(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        isolate_overlay(self.tmp)
        os.environ["XDG_STATE_HOME"] = str(self.tmp / "state")
        self.state = self.tmp / "state" / "android-iac"

    def use(self, managed: Any) -> None:
        self.spec = spec_file(self.tmp, spec_with(managed))

    def run_cli(self, phone: FakeAdb, *argv: str, answers: Sequence[str] = ()) -> tuple[int, str]:
        queue = list(answers)
        with contextlib.redirect_stdout(io.StringIO()) as out, contextlib.redirect_stderr(io.StringIO()), \
                unittest.mock.patch.object(cli, "_ask", lambda prompt, secret: queue.pop(0)):
            code = cli.main(["--spec", self.spec, *argv], phone)
        return code, out.getvalue()

    def rehearsed(self, phone: FakeAdb) -> None:
        self.assertEqual(self.run_cli(phone, "plan")[0], 1)
        self.assertEqual(self.run_cli(phone, "apply", "--dry-run")[0], 0)

    def journal(self) -> list[dict[str, Any]]:
        (path,) = (self.state / "journal").iterdir()
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        return [json.loads(x) for x in path.read_text().splitlines()]

    def test_apply_then_rollback_settings_and_packages(self) -> None:
        self.use({"settings": MANAGED["settings"], "packagesDisabled": ["org.example.notes"]})
        phone = Phone({**healthy(), TIMEOUT: "30000\n"})
        self.rehearsed(phone)
        code, out = self.run_cli(phone, "apply", answers=["apply"])
        self.assertEqual(code, 0, out)
        self.assertEqual(phone.answers[TIMEOUT], "60000\n")
        self.assertIn("package:org.example.notes", str(phone.answers[DISABLED]))
        self.assertEqual([e["result"] for e in self.journal()], ["ok", "ok"])
        self.assertEqual(self.run_cli(phone, "plan")[0], 0)  # idempotent: nothing left to change
        code, out = self.run_cli(phone, "rollback", answers=["rollback"])
        self.assertEqual(code, 0, out)
        self.assertEqual(phone.answers[TIMEOUT], "30000\n")
        self.assertNotIn("package:org.example.notes", str(phone.answers[DISABLED]))
        self.assertIn("nothing to undo", self.run_cli(phone, "rollback")[1])

    def test_an_unset_key_is_deleted_on_rollback(self) -> None:
        self.use(SETTINGS_ONLY)
        phone = Phone({**healthy(), TIMEOUT: "null\n"})
        self.rehearsed(phone)
        self.run_cli(phone, "apply", answers=["apply"])
        self.run_cli(phone, "rollback", answers=["rollback"])
        self.assertIn(("shell", "settings", "delete", "system", "screen_off_timeout"), phone.calls)
        self.assertEqual(phone.answers[TIMEOUT], "null\n")

    def test_no_rehearsal_a_stale_one_or_no_typed_yes_runs_nothing(self) -> None:
        self.use(SETTINGS_ONLY)
        phone = Phone({**healthy(), TIMEOUT: "30000\n"})
        self.run_cli(phone, "plan")
        self.assertIn("not rehearsed", self.run_cli(phone, "apply", answers=["apply"])[1])
        self.run_cli(phone, "apply", "--dry-run")
        (mark,) = (self.state / "rehearsals").iterdir()
        old = (dt.datetime.now().astimezone() - dt.timedelta(minutes=11)).isoformat()
        mark.write_text(json.dumps({**json.loads(mark.read_text()), "rehearsed": old}))
        self.assertIn("older than 10 minutes", self.run_cli(phone, "apply", answers=["apply"])[1])
        self.run_cli(phone, "apply", "--dry-run")
        self.assertEqual(self.run_cli(phone, "apply", answers=["yes"])[0], 1)
        self.assertFalse([c for c in phone.calls if allowed_write(c)])
        self.assertEqual(phone.answers[TIMEOUT], "30000\n")

    def test_a_write_that_does_not_land_stops_the_run(self) -> None:
        self.use({"settings": MANAGED["settings"], "packagesDisabled": ["org.example.notes"]})
        phone = Phone({**healthy(), TIMEOUT: "30000\n"}, refuse="org.example.notes")
        self.rehearsed(phone)
        code, out = self.run_cli(phone, "apply", answers=["apply"])
        self.assertEqual(code, 1)
        self.assertIn("unverified", out)
        self.assertEqual([e["result"] for e in self.journal()], ["ok", "unverified"])

    def test_rollback_leaves_what_was_changed_by_hand(self) -> None:
        self.use(SETTINGS_ONLY)
        phone = Phone({**healthy(), TIMEOUT: "30000\n"})
        self.rehearsed(phone)
        self.run_cli(phone, "apply", answers=["apply"])
        phone.answers[TIMEOUT] = "120000\n"
        code, out = self.run_cli(phone, "rollback", answers=["rollback"])
        self.assertEqual(code, 1)
        self.assertIn("changed since apply", out)
        self.assertEqual(phone.answers[TIMEOUT], "120000\n")

    def test_sensitive_needs_its_name_typed(self) -> None:
        self.use({"permissionsRevoked": {"org.example.notes": ["android.permission.RECORD_AUDIO"]}})
        phone = Phone(healthy())
        self.rehearsed(phone)
        self.assertEqual(self.run_cli(phone, "apply", answers=["apply", "yes"])[0], 1)
        self.assertFalse([c for c in phone.calls if allowed_write(c)])
        self.assertTrue(plan.Op("pm-revoke", "a b", "granted", "revoked").sensitive)


if __name__ == "__main__":
    unittest.main()
