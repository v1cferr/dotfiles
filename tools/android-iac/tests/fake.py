"""A scripted adb: each argv maps to fixture text, a failure, or a timeout. Nothing touches a device."""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Sequence, Union

from adb import CommandFailed, Result

FIXTURES = Path(__file__).parent / "fixtures"
SPEC: dict[str, Any] = {
    "name": "test-phone", "manufacturer": "motorola", "model": None, "address": "192.168.1.31",
    "security": {
        "props": {"ro.boot.verifiedbootstate": "green", "ro.boot.flash.locked": "1",
                  "ro.boot.vbmeta.device_state": "locked", "ro.build.type": "user"},
        "selinux": "Enforcing", "nfc": "on", "lockScreenRequired": True, "maxPatchAgeDays": 120},
    "settings": {"global": {"auto_time": "1", "stay_on_while_plugged_in": "0"},
                 "secure": {"enabled_accessibility_services": None}},
    "manualSettings": {"global": {"adb_enabled": "0"}},
    "packages": {"mustBeEnabled": ["com.android.nfc", "com.android.vending", "com.motorola.absent"]},
    "permissions": {"flagged": ["android.permission.RECORD_AUDIO", "android.permission.READ_SMS"]},
}

Answer = Union[str, Result, Exception]


def fixture(name: str) -> str:
    return (FIXTURES / name).read_text()


def healthy() -> dict[tuple[str, ...], Answer]:
    return {
        ("version",): "Android Debug Bridge version 1.0.41\n",
        ("devices", "-l"): fixture("devices-one.txt"),
        ("shell", "getprop"): fixture("getprop.txt"),
        ("shell", "getenforce"): "Enforcing\n",
        ("shell", "dumpsys", "nfc"): fixture("dumpsys-nfc.txt"),
        ("shell", "cmd", "lock_settings", "get-disabled"): "false\n",
        ("shell", "pm", "list", "packages"): fixture("pm-all.txt"),
        ("shell", "pm", "list", "packages", "-e"): fixture("pm-enabled.txt"),
        ("shell", "pm", "list", "packages", "-d"): fixture("pm-disabled.txt"),
        ("shell", "pm", "list", "packages", "-3"): fixture("pm-third.txt"),
        ("shell", "pm", "list", "packages", "-s"): fixture("pm-all.txt"),
        ("shell", "settings", "get", "global", "auto_time"): "1\n",
        ("shell", "settings", "get", "global", "stay_on_while_plugged_in"): "0\n",
        ("shell", "settings", "get", "secure", "enabled_accessibility_services"): "null\n",
        ("shell", "settings", "get", "global", "adb_enabled"): "1\n",
        ("shell", "settings", "list", "global"): fixture("settings-global.txt"),
        ("shell", "settings", "list", "secure"): "",
        ("shell", "settings", "list", "system"): "",
        ("shell", "dumpsys", "package", "org.example.notes"): fixture("dumpsys-package.txt"),
        ("shell", "dumpsys", "package", "br.example.bank"): "",
        ("shell", "dumpsys", "package", "com.android.settings"): "",
    }


class FakeAdb:
    def __init__(self, answers: dict[tuple[str, ...], Answer]) -> None:
        self.answers = answers
        self.calls: list[tuple[str, ...]] = []
        self.inputs: list[str | None] = []

    def __call__(self, args: Sequence[str], input: str | None = None) -> Result:
        key = tuple(args)
        self.calls.append(key)
        self.inputs.append(input)
        answer = self.answers.get(key, Result(1, "", "error: unknown command for this fake"))
        if isinstance(answer, Exception):
            raise answer
        return answer if isinstance(answer, Result) else Result(0, answer, "")


def timeout() -> CommandFailed:
    return CommandFailed("adb shell getenforce timed out after 20s")


def spec_file(tmp: Path, data: Any = None) -> str:
    path = tmp / "spec.json"
    path.write_text(json.dumps(SPEC if data is None else data))
    return str(path)


def isolate_overlay(tmp: Path) -> None:
    """Point XDG_CONFIG_HOME at an empty place, so a real ~/.config overlay never leaks into a test."""
    os.environ["XDG_CONFIG_HOME"] = str(tmp)
    os.environ.pop("ANDROID_SERIAL", None)
