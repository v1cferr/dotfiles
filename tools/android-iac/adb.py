"""The ONLY place android-iac runs a process: every argv is checked against a read-only allowlist."""

from __future__ import annotations

import re
import shutil
import subprocess
from dataclasses import dataclass
from typing import Callable, Optional, Sequence

NAMESPACES = frozenset({"global", "secure", "system"})
PM_FILTERS = frozenset({"-d", "-e", "-s", "-3"})
SETTING_KEY = re.compile(r"^[A-Za-z0-9_.]{1,128}$")
PACKAGE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$")
TIMEOUT_S = 20


class AdbError(Exception):
    """A failure the user can act on; the message says how."""


class AdbMissing(AdbError):
    pass


class NoDevice(AdbError):
    pass


class Unauthorized(AdbError):
    pass


class MultipleDevices(AdbError):
    pass


class CommandFailed(AdbError):
    pass


class Refused(AdbError):
    """An argv outside the allowlist. Raised BEFORE anything runs: phase 1 never writes."""


@dataclass(frozen=True)
class Result:
    code: int
    stdout: str
    stderr: str


Runner = Callable[[Sequence[str]], Result]


def allowed(args: Sequence[str]) -> bool:
    """True only for the read-only shapes phase 1 needs. Arguments reach a remote shell, so
    every free-form one is matched against a strict pattern first."""
    a = list(args)
    if a in (["version"], ["devices", "-l"], ["shell", "getprop"], ["shell", "getenforce"],
             ["shell", "dumpsys", "nfc"], ["shell", "cmd", "lock_settings", "get-disabled"]):
        return True
    if a[:4] == ["shell", "pm", "list", "packages"]:
        rest = a[4:]
        return len(rest) <= 1 and all(f in PM_FILTERS for f in rest)
    if a[:3] == ["shell", "settings", "get"] and len(a) == 5:
        return a[3] in NAMESPACES and bool(SETTING_KEY.match(a[4]))
    if a[:3] == ["shell", "settings", "list"] and len(a) == 4:
        return a[3] in NAMESPACES
    if a[:3] == ["shell", "dumpsys", "package"] and len(a) == 4:
        return bool(PACKAGE.match(a[3]))
    return False


def subprocess_runner(target: Sequence[str] = ()) -> Runner:
    """The real runner. `target` is `-s <serial>` or `-t <id>`, prepended after the check."""
    exe = shutil.which("adb")

    def run(args: Sequence[str]) -> Result:
        if exe is None:
            raise AdbMissing("adb is not on PATH: install android-tools (modules/home/apps/android.nix)")
        try:
            p = subprocess.run([exe, *target, *args], capture_output=True, text=True,
                               timeout=TIMEOUT_S, check=False)
        except subprocess.TimeoutExpired as e:
            raise CommandFailed(f"adb {' '.join(args)} timed out after {TIMEOUT_S}s") from e
        return Result(p.returncode, p.stdout, p.stderr)

    return run


class Adb:
    """Allowlisted, read-only access to one adb target."""

    def __init__(self, runner: Runner) -> None:
        self._run = runner

    def call(self, *args: str) -> str:
        if not allowed(args):
            raise Refused(f"refused, not a read-only command: adb {' '.join(args)}")
        r = self._run(args)
        if r.code != 0:
            err = (r.stderr or r.stdout).strip().splitlines()
            last = err[-1] if err else f"exit {r.code}"
            if "unauthorized" in last:
                raise Unauthorized("the phone has not authorized this computer: accept the prompt on it")
            if "no devices" in last or "not found" in last:
                raise NoDevice("no phone reachable: connect USB or `adb connect <address>:<port>`")
            if "more than one" in last:
                raise MultipleDevices("several devices: pick one with --serial or --transport-id")
            raise CommandFailed(f"adb {' '.join(args)} failed: {last}")
        return r.stdout

    def try_call(self, *args: str) -> Optional[str]:
        """The output, or None when the device would not answer this one read."""
        try:
            return self.call(*args)
        except CommandFailed:
            return None
