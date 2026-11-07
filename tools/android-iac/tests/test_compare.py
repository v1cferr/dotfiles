"""Declared against observed: sync, drift, unknown, unsupported, manual; and the spec's validation."""

from __future__ import annotations

import copy
import datetime as dt
import json
import os
import unittest
from pathlib import Path
from typing import Any

import compare
import state
from adb import Adb, AdbError, MultipleDevices, NoDevice, Unauthorized
from compare import Status
from fake import SPEC, FakeAdb, fixture, healthy, timeout
from spec import SpecError, parse

TODAY = dt.date(2026, 11, 7)


def run(answers: dict[tuple[str, ...], Any], data: dict[str, Any] = SPEC, local: Any = None,
        perms: bool = False) -> dict[str, compare.Finding]:
    spec = parse(data, local)
    observed = state.observe(Adb(FakeAdb(answers)), spec, perms)
    return {f.check: f for f in compare.findings(spec, observed, TODAY)}


class Compare(unittest.TestCase):
    def test_healthy_phone(self) -> None:
        fs = run(healthy())
        self.assertEqual(fs["prop ro.boot.verifiedbootstate"].status, Status.IN_SYNC)
        self.assertEqual(fs["selinux"].status, Status.IN_SYNC)
        self.assertEqual(fs["nfc"].status, Status.IN_SYNC)
        self.assertEqual(fs["security patch"].status, Status.IN_SYNC)
        self.assertEqual(fs["setting secure.enabled_accessibility_services"].status, Status.IN_SYNC)
        # a swipe lock reads "not disabled" too, so it is never declared in sync
        self.assertEqual(fs["lock screen"].status, Status.MANUAL)
        self.assertEqual(fs["setting global.adb_enabled"].status, Status.MANUAL)
        self.assertEqual(fs["package com.android.vending"].status, Status.DRIFT)
        self.assertEqual(fs["package com.motorola.absent"].status, Status.UNSUPPORTED)

    def test_real_drift(self) -> None:
        answers = healthy()
        answers[("shell", "getprop")] = fixture("getprop-drift.txt")
        answers[("shell", "settings", "get", "global", "auto_time")] = "0\n"
        answers[("shell", "settings", "get", "secure", "enabled_accessibility_services")] = "com.evil/.Svc\n"
        fs = run(answers)
        for check in ("prop ro.boot.verifiedbootstate", "prop ro.boot.flash.locked", "security patch",
                      "setting global.auto_time", "setting secure.enabled_accessibility_services"):
            self.assertEqual(fs[check].status, Status.DRIFT, check)
        self.assertEqual(fs["setting secure.enabled_accessibility_services"].observed, "com.evil/.Svc")
        self.assertEqual(compare.exit_code(list(fs.values())), 1)

    def test_no_evidence_is_unknown_never_in_sync(self) -> None:
        answers = healthy()
        answers[("shell", "getenforce")] = timeout()
        answers[("shell", "getprop")] = "[ro.product.manufacturer]: [motorola]\n"
        del answers[("shell", "dumpsys", "nfc")]
        del answers[("shell", "settings", "get", "global", "stay_on_while_plugged_in")]
        answers[("shell", "settings", "get", "global", "auto_time")] = "null\n"
        del answers[("shell", "pm", "list", "packages")]
        fs = run(answers)
        for check in ("selinux", "nfc", "prop ro.boot.verifiedbootstate", "security patch",
                      "setting global.stay_on_while_plugged_in", "setting global.auto_time",
                      "package com.android.nfc"):
            self.assertEqual(fs[check].status, Status.UNKNOWN, check)

    def test_exit_codes(self) -> None:
        f = compare.Finding
        self.assertEqual(compare.exit_code([f(Status.IN_SYNC, "a", "1", "1")]), 0)
        self.assertEqual(compare.exit_code([f(Status.IN_SYNC, "a", "1", "1"), f(Status.UNKNOWN, "b", None, "1")]), 3)
        self.assertEqual(compare.exit_code([f(Status.MANUAL, "a", "1", "0"), f(Status.DRIFT, "b", "0", "1")]), 1)

    def test_local_overlay_and_permissions(self) -> None:
        fs = run(healthy(), local={"mustBeInstalled": ["br.example.bank", "br.example.missing"]}, perms=True)
        self.assertEqual(fs["app br.example.bank (local)"].status, Status.IN_SYNC)
        self.assertEqual(fs["app br.example.missing (local)"].status, Status.DRIFT)
        self.assertEqual(fs["permission org.example.notes"].observed, "RECORD_AUDIO")

    def test_another_phone_is_refused(self) -> None:
        data = copy.deepcopy(SPEC)
        data["model"] = "SM-M515F"
        with self.assertRaises(AdbError):
            run(healthy(), data)


class Selection(unittest.TestCase):
    def test_states(self) -> None:
        for name, error in (("devices-none.txt", NoDevice), ("devices-unauthorized.txt", Unauthorized),
                            ("devices-two.txt", MultipleDevices)):
            with self.assertRaises(error, msg=name):
                state.select(Adb(FakeAdb({("devices", "-l"): fixture(name)})))

    def test_transport_id_picks_one_of_two(self) -> None:
        adb = Adb(FakeAdb({("devices", "-l"): fixture("devices-two.txt")}))
        self.assertEqual(state.select(adb, "3").transport, "tcp")
        with self.assertRaises(NoDevice):
            state.select(adb, "9")


class Spec(unittest.TestCase):
    def test_rejects_bad_declarations(self) -> None:
        bad: list[dict[str, Any]] = [
            {"settings": {"vendor": {"x": "1"}}},
            {"settings": {"global": {"a b": "1"}}},
            {"settings": {"global": {"x": 1}}},
            {"manualSettings": {"global": {"auto_time": "1"}}},
            {"packages": {"mustBeEnabled": ["not a package"]}},
            {"packages": {"mustBeEnabled": ["com.a.b", "com.a.b"]}},
            {"security": {"selinux": "Off"}},
            {"security": {"maxPatchAgeDays": 0}},
            {"security": {"props": {"persist.x": "1"}}},
            {"permissions": {"flagged": ["READ_SMS"]}},
        ]
        for patch in bad:
            data = {**copy.deepcopy(SPEC), **patch}
            if "manualSettings" in patch:
                data["settings"] = {"global": {"auto_time": "1"}}
            with self.assertRaises(SpecError, msg=json.dumps(patch)):
                parse(data)
        with self.assertRaises(SpecError):
            parse(SPEC, {"mustBeInstalled": "br.example.bank"})

    @unittest.skipUnless(os.environ.get("ANDROID_IAC_SPEC"), "the packaged host spec is set at build")
    def test_the_real_host_spec_is_valid(self) -> None:
        spec = parse(json.loads(Path(os.environ["ANDROID_IAC_SPEC"]).read_text()))
        self.assertEqual(spec.name, "motorola-edge-70-fusion")


if __name__ == "__main__":
    unittest.main()
