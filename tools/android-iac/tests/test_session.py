"""`audit`: discovery, pairing, connecting, and always disconnecting; all against a stateful fake."""

from __future__ import annotations

import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from typing import Optional, Sequence

import cli
import session
from adb import Adb, Refused, Result, allowed_session
from fake import FakeAdb, fixture, healthy, isolate_overlay, spec_file
from spec import load

AVAHI = (
    "+;wlan0;IPv4;adb-SYNTHETIC;_adb-tls-connect._tcp;local\n"
    "=;wlan0;IPv4;adb-OTHER;_adb-tls-connect._tcp;local;other.local;192.168.1.77;40001;\n"
    "=;wlan0;IPv4;adb-SYNTHETIC;_adb-tls-connect._tcp;local;phone.local;192.168.1.31;40123;\n"
)


class Phone(FakeAdb):
    """No device until `connect` succeeds; `paired` decides whether it does."""

    def __init__(self, paired: bool) -> None:
        super().__init__({**healthy(), ("devices", "-l"): fixture("devices-none.txt")})
        self.paired = paired

    def __call__(self, args: Sequence[str], input: Optional[str] = None) -> Result:
        if args and args[0] in ("connect", "pair", "disconnect"):
            self.calls.append(tuple(args))
            self.inputs.append(input)
            if args[0] == "pair":
                self.paired = input == "123456\n"
                return Result(0, "Successfully paired to 192.168.1.31:41000" if self.paired else "Failed: Wrong password", "")
            if args[0] == "connect" and self.paired:
                self.answers[("devices", "-l")] = fixture("devices-one.txt")
                return Result(0, f"connected to {args[1]}", "")
            if args[0] == "connect":
                return Result(0, f"failed to connect to '{args[1]}': failed to authenticate", "")
            return Result(0, f"disconnected {args[1]}", "")
        return super().__call__(args, input)


class Audit(unittest.TestCase):
    def setUp(self) -> None:
        tmp = Path(tempfile.mkdtemp())
        isolate_overlay(tmp)
        self.spec_path = spec_file(tmp)
        self.spec, _ = load(self.spec_path, None)

    def audit(self, phone: FakeAdb, answers: list[str], avahi: str = "") -> tuple[int, str, str]:
        queue = list(answers)
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = cli.audit(Adb(phone), self.spec, (self.spec_path, None), False, None, phone,
                             ask=lambda prompt, secret: queue.pop(0), browse=lambda service: avahi)
        return code, out.getvalue(), err.getvalue()

    def test_discovered_and_paired(self) -> None:
        phone = Phone(paired=True)
        code, out, _ = self.audit(phone, [], AVAHI)
        self.assertEqual(code, 1)  # the healthy fixture carries one disabled package
        self.assertIn(("connect", "192.168.1.31:40123"), phone.calls)
        self.assertEqual(phone.calls[-1], ("disconnect", "192.168.1.31:40123"))
        for section in ("== doctor ==", "== inspect ==", "== diff ==", "Revoke USB debugging"):
            self.assertIn(section, out)

    def test_pairs_with_the_code_on_stdin(self) -> None:
        phone = Phone(paired=False)
        code, out, _ = self.audit(phone, ["40123", "41000", "123456"])
        self.assertEqual(code, 1)
        self.assertIn(("pair", "192.168.1.31:41000"), phone.calls)
        self.assertIn("123456\n", phone.inputs)
        self.assertNotIn("123456", " ".join(" ".join(c) for c in phone.calls))
        self.assertNotIn("123456", out)

    def test_a_wrong_code_stops_cleanly(self) -> None:
        phone = Phone(paired=False)
        code, out, err = self.audit(phone, ["40123", "41000", "654321"])
        self.assertEqual(code, 2)
        self.assertIn("pairing failed", err)
        self.assertNotIn("654321", out + err)
        self.assertFalse(any(c[0] == "disconnect" for c in phone.calls))

    def test_bad_answers_are_refused(self) -> None:
        for answers in (["not-a-port"], ["40123", "612639"], ["40123", "41000", "12ab"]):
            code, _, err = self.audit(Phone(paired=False), answers)
            self.assertEqual(code, 2, answers)

    def test_an_attached_device_is_used_and_left_alone(self) -> None:
        phone = FakeAdb(healthy())
        code, out, _ = self.audit(phone, [])
        self.assertEqual(code, 1)
        self.assertFalse(any(c[0] in ("connect", "disconnect") for c in phone.calls))
        self.assertIn("Revoke USB debugging", out)


class Session(unittest.TestCase):
    def test_discover_matches_the_declared_address_only(self) -> None:
        self.assertEqual(session.discover(lambda s: AVAHI, "_adb-tls-connect._tcp", "192.168.1.31"), "40123")
        self.assertIsNone(session.discover(lambda s: AVAHI, "_adb-tls-connect._tcp", "192.168.1.32"))
        self.assertIsNone(session.discover(lambda s: "", "_adb-tls-connect._tcp", "192.168.1.31"))

    def test_session_allowlist(self) -> None:
        self.assertTrue(allowed_session(("connect", "192.168.1.31:40123")))
        for bad in (("connect", "192.168.1.31:1; reboot"), ("pair", "192.168.1.31:1", "123456"),
                    ("connect", "phone.local:5555"), ("tcpip", "5555"), ("disconnect",)):
            self.assertFalse(allowed_session(bad), bad)
            with self.assertRaises(Refused):
                Adb(FakeAdb({})).session(*bad)

    def test_ctrl_c_is_exit_130_without_a_traceback(self) -> None:
        def interrupted(argv: object = None, runner: object = None) -> int:
            raise KeyboardInterrupt
        main, cli.main = cli.main, interrupted
        try:
            with contextlib.redirect_stderr(io.StringIO()) as err:
                self.assertEqual(cli.run(), 130)
        finally:
            cli.main = main
        self.assertIn("interrupted", err.getvalue())

    def test_cli_wires_audit(self) -> None:
        with contextlib.redirect_stdout(io.StringIO()) as out:
            with self.assertRaises(SystemExit):
                cli.main(["--help"])
        self.assertIn("audit", out.getvalue())


if __name__ == "__main__":
    unittest.main()
