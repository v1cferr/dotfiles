"""`android-iac doctor`: what works between this computer and the phone, and what to do when not."""

from __future__ import annotations

import os
from typing import Optional

import parse
from adb import Adb, AdbError
from spec import SpecError, load

TRAPS = (
    "wireless debugging: the connect port changes on every toggle, `adb connect <address>:<new port>`",
    "wireless debugging turns itself off when the phone leaves the WiFi network it was enabled on",
    "the fixed address is a reservation for a RANDOMIZED MAC: changing the network's privacy setting loses it",
    "when done: Developer options, Revoke USB debugging authorizations, and turn both debugging toggles off",
)

# One harmless read per capability the other commands rely on.
PROBES = (
    ("properties", ("shell", "getprop")),
    ("selinux", ("shell", "getenforce")),
    ("packages", ("shell", "pm", "list", "packages", "-s")),
    ("settings", ("shell", "settings", "get", "global", "auto_time")),
    ("nfc", ("shell", "dumpsys", "nfc")),
    ("lock screen", ("shell", "cmd", "lock_settings", "get-disabled")),
    ("permissions", ("shell", "dumpsys", "package", "com.android.settings")),
)


def _line(ok: Optional[bool], what: str, detail: str = "") -> None:
    mark = {True: "ok  ", False: "FAIL", None: "--  "}[ok]
    print(f"[{mark}] {what}" + (f": {detail}" if detail else ""))


def doctor(adb: Adb, spec_path: Optional[str], local: Optional[str], transport_id: Optional[str]) -> int:
    """0 when every check passed, 2 when the environment blocks the other commands."""
    healthy = True
    spec = None
    try:
        spec, overlay = load(spec_path, local)
        _line(True, "spec", f"{spec.name}, {len(spec.settings) + len(spec.manual_settings)} settings declared")
        _line(None, "local overlay", f"read {overlay}" if overlay else "none, so private apps are not checked")
    except SpecError as e:
        healthy = False
        _line(False, "spec", str(e))

    try:
        version = adb.call("version").splitlines()
        _line(True, "adb", version[0] if version else "present")
        devices = parse.devices(adb.call("devices", "-l"))
    except AdbError as e:
        _line(False, "adb", str(e))
        return 2

    if transport_id is not None:
        devices = [d for d in devices if d.transport_id == transport_id]
    for d in devices:
        _line(d.state == "device", f"device {d.transport}:{d.transport_id}", f"{d.state}, model {d.model or '?'}")
    ready = [d for d in devices if d.state == "device"]
    if not devices:
        _line(False, "device", "none: plug USB, or pair and `adb connect` (docs/guides/android-adb-session.md)")
    elif any(d.state == "unauthorized" for d in devices):
        _line(False, "authorization", "unlock the phone and accept the RSA prompt for this computer")
    if len(ready) > 1 and "ANDROID_SERIAL" not in os.environ:
        _line(False, "selection", "several devices are ready: pass --transport-id")
    if len(ready) != 1 and not (ready and "ANDROID_SERIAL" in os.environ):
        healthy = False
    else:
        props = parse.getprop(adb.try_call("shell", "getprop") or "")
        if spec is not None:
            for want, key in ((spec.manufacturer, "ro.product.manufacturer"), (spec.model, "ro.product.model")):
                got = props.get(key)
                if want is None:
                    _line(None, key, f"not declared yet; the device says {got!r}")
                else:
                    match = got is not None and got.lower() == want.lower()
                    healthy &= match
                    _line(match, key, f"device {got!r}, spec {want!r}")
        _line(None, "android", f"{props.get('ro.build.version.release', '?')} (API {props.get('ro.build.version.sdk', '?')})")
        for name, probe in PROBES:
            _line(adb.try_call(*probe) is not None, f"read {name}")

    print("\nKnown traps:")
    for t in TRAPS:
        print(f"  - {t}")
    return 0 if healthy else 2
