"""Fail-safe redaction: a property leaves only if allowlisted, a setting only if its key is not
identity-shaped AND its value is a short number; any string is scrubbed again before printing."""

from __future__ import annotations

import re
from typing import Any, Optional

REDACTED = "<redacted>"

# Build and boot facts; nothing here identifies a unit, a person or a network.
PROPS = frozenset({
    "ro.product.manufacturer", "ro.product.brand", "ro.product.model", "ro.product.device",
    "ro.product.name", "ro.product.first_api_level", "ro.board.platform", "ro.soc.model",
    "ro.build.version.release", "ro.build.version.sdk", "ro.build.version.security_patch",
    "ro.vendor.build.security_patch", "ro.build.fingerprint", "ro.build.id", "ro.build.type",
    "ro.build.tags", "ro.boot.verifiedbootstate", "ro.boot.flash.locked",
    "ro.boot.vbmeta.device_state", "ro.boot.veritymode", "ro.debuggable", "ro.secure",
    "ro.adb.secure", "ro.crypto.state", "ro.crypto.type", "ro.build.version.incremental",
})

# A key that names a person, a unit, a network or an account never leaves, whatever its value.
IDENTITY_KEY = re.compile(
    r"(name|ssid|bssid|address|mac|serial|imei|meid|android_id|account|token|password|secret|"
    r"email|phone|number|location|uuid|iccid|imsi|_id$)", re.IGNORECASE)
NUMERIC = re.compile(r"^-?\d{1,9}(\.\d+)?$")
# Package and component lists (`pkg/.Service:pkg2/.Other`): app names, which a local report needs.
COMPONENTS = re.compile(r"^[A-Za-z][\w.]*(/[\w.$]+)?(:[A-Za-z][\w.]*(/[\w.$]+)?)*$")

# The last net, over every string printed: IMEI-length digit runs, MACs, e-mail addresses.
IMEI = re.compile(r"(?<!\d)\d{14,16}(?!\d)")
MAC = re.compile(r"\b[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}\b")
EMAIL = re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.-]+\b")


def props(raw: dict[str, str]) -> dict[str, str]:
    return {k: scrub(v) for k, v in sorted(raw.items()) if k in PROPS}


def setting_value(key: str, value: Optional[str]) -> Optional[str]:
    """A value fit to print. Declared keys go through here too: a declaration is not consent."""
    if value is None:
        return None
    if IDENTITY_KEY.search(key):
        return REDACTED
    if NUMERIC.match(value) or (COMPONENTS.match(value) and "." in value):
        return value
    return REDACTED


def settings(raw: dict[str, str]) -> dict[str, Optional[str]]:
    return {k: setting_value(k, v) for k, v in sorted(raw.items())}


def scrub(text: str) -> str:
    text = IMEI.sub(REDACTED, text)
    text = MAC.sub(REDACTED, text)
    return EMAIL.sub(REDACTED, text)


def deep_scrub(value: Any) -> Any:
    """The final pass over a whole report, so a new field cannot skip redaction."""
    if isinstance(value, str):
        return scrub(value)
    if isinstance(value, dict):
        return {k: deep_scrub(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [deep_scrub(v) for v in value]
    return value
