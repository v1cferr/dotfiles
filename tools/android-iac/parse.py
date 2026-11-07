"""Parsers for adb's text output. Each one tolerates odd or missing lines and never raises on them."""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Optional

PROP = re.compile(r"^\[([^\]]+)\]: \[(.*)\]$")
GRANTED = re.compile(r"^\s+([\w.]+): granted=true")


@dataclass(frozen=True)
class Device:
    """One line of `adb devices -l`, WITHOUT the serial: devices are addressed by transport id."""

    state: str
    transport: str
    transport_id: Optional[str]
    model: Optional[str]


def devices(text: str) -> list[Device]:
    out = []
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 2 or line.startswith(("List of devices", "*")):
            continue
        serial, state, fields = parts[0], parts[1], dict(
            f.split(":", 1) for f in parts[2:] if ":" in f)
        if "usb" in fields:
            transport = "usb"
        elif ":" in serial or "_adb-tls-connect" in serial:
            transport = "tcp"
        else:
            transport = "other"
        out.append(Device(state, transport, fields.get("transport_id"), fields.get("model")))
    return out


def getprop(text: str) -> dict[str, str]:
    props = {}
    for line in text.splitlines():
        m = PROP.match(line.strip())
        if m:
            props[m.group(1)] = m.group(2)
    return props


def packages(text: str) -> set[str]:
    return {line.strip()[len("package:"):] for line in text.splitlines()
            if line.strip().startswith("package:") and len(line.strip()) > len("package:")}


def setting(text: Optional[str]) -> Optional[str]:
    """`settings get` prints `null` for an unset key; both that and no answer read as None."""
    if text is None:
        return None
    value = text.strip()
    return None if value in ("", "null") else value


def settings_list(text: str) -> dict[str, str]:
    out = {}
    for line in text.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            if key.strip():
                out[key.strip()] = value.strip()
    return out


def selinux(text: Optional[str]) -> Optional[str]:
    value = (text or "").strip()
    return value if value in ("Enforcing", "Permissive", "Disabled") else None


def nfc(text: Optional[str]) -> Optional[str]:
    m = re.search(r"mState=(\w+)", text or "")
    return m.group(1).lower() if m else None


def lock_disabled(text: Optional[str]) -> Optional[bool]:
    value = (text or "").strip().lower()
    return {"true": True, "false": False}.get(value)


def granted_runtime(text: str) -> set[str]:
    """Runtime permissions granted in `dumpsys package <pkg>`, for user 0's block and any other."""
    granted: set[str] = set()
    inside = False
    for line in text.splitlines():
        if line.strip() == "runtime permissions:":
            inside = True
            continue
        if inside:
            m = GRANTED.match(line)
            if m:
                granted.add(m.group(1))
            elif line.strip() and not line.startswith(" " * 6):
                inside = False
    return granted
