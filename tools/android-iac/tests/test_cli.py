"""The commands end to end over the fake: exit codes, messages, and nothing private on stdout."""

from __future__ import annotations

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from typing import Any

import cli
from adb import AdbMissing
from fake import FakeAdb, fixture, healthy, isolate_overlay, spec_file


class Cli(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        isolate_overlay(self.tmp)
        self.spec = spec_file(self.tmp)

    def run_cli(self, *argv: str, answers: Any = None) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = cli.main(["--spec", self.spec, *argv], FakeAdb(healthy() if answers is None else answers))
        return code, out.getvalue(), err.getvalue()

    def test_inspect_json_is_sanitized(self) -> None:
        code, out, _ = self.run_cli("inspect", "--json", "--permissions")
        self.assertEqual(code, 0)
        report = json.loads(out)
        self.assertEqual(report["boot"]["verifiedBoot"], "green")
        self.assertEqual(report["settings"]["global"]["device_name"], "<redacted>")
        for secret in ("ZY22SYNTHETIC", "356938035643809", "someone@example.com", "MyHomeNet",
                       "Someone", "192.168.1.31:40123"):
            self.assertNotIn(secret, out)

    def test_diff_and_verify_exit_on_drift(self) -> None:
        code, out, _ = self.run_cli("diff")
        self.assertEqual(code, 1)
        self.assertIn("in-sync", out)
        self.assertIn("no local overlay", out)
        code, out, _ = self.run_cli("verify")
        self.assertEqual(code, 1)
        self.assertNotIn("in-sync      prop", out)
        code, out, _ = self.run_cli("verify", "--json")
        self.assertEqual(json.loads(out)["exit"], 1)

    def test_no_device_unauthorized_and_two_devices(self) -> None:
        for name, words in (("devices-none.txt", "no phone attached"),
                            ("devices-unauthorized.txt", "not authorized"),
                            ("devices-two.txt", "--transport-id")):
            code, out, err = self.run_cli("diff", answers={("devices", "-l"): fixture(name)})
            self.assertEqual(code, 2, name)
            self.assertIn(words, err)
            self.assertEqual(out, "")

    def test_missing_adb(self) -> None:
        def no_adb(args: object) -> None:
            raise AdbMissing("adb is not on PATH")
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(cli.main(["--spec", self.spec, "doctor"], no_adb), 2)  # type: ignore[arg-type]
        self.assertIn("adb is not on PATH", out.getvalue())

    def test_doctor_healthy_and_without_device(self) -> None:
        code, out, _ = self.run_cli("doctor")
        self.assertEqual(code, 0, out)
        self.assertIn("not declared yet", out)
        self.assertIn("[ok  ] read nfc", out)
        code, out, _ = self.run_cli("doctor", answers={**healthy(), ("devices", "-l"): fixture("devices-none.txt")})
        self.assertEqual(code, 2)
        self.assertIn("android-adb-session.md", out)

    def test_bad_spec_is_an_environment_error(self) -> None:
        self.spec = spec_file(self.tmp, {"name": "x", "settings": {"vendor": {}}})
        code, _, err = self.run_cli("diff")
        self.assertEqual(code, 2)
        self.assertIn("unknown namespace", err)

    def test_local_overlay_is_read_from_xdg(self) -> None:
        (self.tmp / "android-iac").mkdir()
        (self.tmp / "android-iac" / "local.json").write_text(json.dumps({"mustBeInstalled": ["br.example.bank"]}))
        code, out, _ = self.run_cli("diff")
        self.assertIn("app br.example.bank (local)", out)
        self.assertNotIn("no local overlay", out)
        code, _, err = self.run_cli("--local", str(self.tmp / "nope.json"), "diff")
        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
