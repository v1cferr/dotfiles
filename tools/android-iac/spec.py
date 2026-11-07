"""The declared state: the host's JSON (from Nix) plus the optional local, untracked overlay."""

from __future__ import annotations

import hashlib
import json
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

import managed as managed_block
from adb import NAMESPACES, PACKAGE, SETTING_KEY


class SpecError(Exception):
    """A declaration that cannot be checked as written."""


@dataclass(frozen=True)
class Spec:
    name: str
    manufacturer: Optional[str]
    model: Optional[str]
    address: Optional[str]
    props: dict[str, str]
    selinux: Optional[str]
    max_patch_age_days: Optional[int]
    nfc: Optional[str]
    lock_screen_required: Optional[bool]
    settings: dict[tuple[str, str], Optional[str]]
    manual_settings: dict[tuple[str, str], Optional[str]]
    must_be_enabled: list[str]
    flagged_permissions: list[str]
    must_be_installed: list[str] = field(default_factory=list)  # from the local overlay only
    managed: managed_block.Managed = field(default_factory=managed_block.Managed)
    digest: str = ""  # sha256 of the declaration, so a plan knows which spec it was made from


def _str_or_none(v: Any, where: str) -> Optional[str]:
    if v is not None and not isinstance(v, str):
        raise SpecError(f"{where}: expected a string or null, got {type(v).__name__}")
    return v


def _settings(raw: Any, where: str) -> dict[tuple[str, str], Optional[str]]:
    if not isinstance(raw, dict):
        raise SpecError(f"{where}: expected an attribute set of namespaces")
    out: dict[tuple[str, str], Optional[str]] = {}
    for ns, keys in raw.items():
        if ns not in NAMESPACES:
            raise SpecError(f"{where}.{ns}: unknown namespace (one of {', '.join(sorted(NAMESPACES))})")
        if not isinstance(keys, dict):
            raise SpecError(f"{where}.{ns}: expected an attribute set of keys")
        for key, value in keys.items():
            if not SETTING_KEY.match(key):
                raise SpecError(f"{where}.{ns}.{key}: not a valid settings key")
            out[(ns, key)] = _str_or_none(value, f"{where}.{ns}.{key}")
    return out


def _packages(raw: Any, where: str) -> list[str]:
    if not isinstance(raw, list) or not all(isinstance(p, str) for p in raw):
        raise SpecError(f"{where}: expected a list of package names")
    bad = [p for p in raw if not PACKAGE.match(p)]
    if bad:
        raise SpecError(f"{where}: not package names: {', '.join(bad)}")
    if len(set(raw)) != len(raw):
        raise SpecError(f"{where}: a package is listed twice")
    return list(raw)


def parse(data: Any, local: Optional[Any] = None) -> Spec:
    if not isinstance(data, dict) or not isinstance(data.get("name"), str):
        raise SpecError("the spec must be an attribute set with a `name`")
    sec = data.get("security") or {}
    props = sec.get("props") or {}
    if not all(isinstance(k, str) and k.startswith("ro.") and isinstance(v, str) for k, v in props.items()):
        raise SpecError("security.props: keys must be `ro.*` properties with string values")
    selinux = _str_or_none(sec.get("selinux"), "security.selinux")
    if selinux not in (None, "Enforcing", "Permissive"):
        raise SpecError("security.selinux: Enforcing, Permissive or null")
    age = sec.get("maxPatchAgeDays")
    if age is not None and (not isinstance(age, int) or isinstance(age, bool) or age <= 0):
        raise SpecError("security.maxPatchAgeDays: a positive integer or null")
    nfc = _str_or_none(sec.get("nfc"), "security.nfc")
    if nfc not in (None, "on", "off"):
        raise SpecError("security.nfc: on, off or null")
    lock = sec.get("lockScreenRequired")
    if lock is not None and not isinstance(lock, bool):
        raise SpecError("security.lockScreenRequired: a boolean or null")
    settings = _settings(data.get("settings") or {}, "settings")
    manual = _settings(data.get("manualSettings") or {}, "manualSettings")
    both = sorted(f"{ns}.{k}" for ns, k in settings.keys() & manual.keys())
    if both:
        raise SpecError(f"declared both audited and manual: {', '.join(both)}")
    flagged = (data.get("permissions") or {}).get("flagged") or []
    if not all(isinstance(p, str) and p.startswith("android.permission.") for p in flagged):
        raise SpecError("permissions.flagged: expected `android.permission.*` names")
    installed: list[str] = []
    if local is not None:
        if not isinstance(local, dict):
            raise SpecError("local overlay: expected a JSON object")
        installed = _packages(local.get("mustBeInstalled") or [], "local overlay mustBeInstalled")
    try:
        managed = managed_block.parse(data.get("managed"), set(settings) | set(manual),
                                      (data.get("packages") or {}).get("mustBeEnabled") or [])
    except ValueError as e:
        raise SpecError(f"managed: {e}") from e
    return Spec(
        name=data["name"],
        manufacturer=_str_or_none(data.get("manufacturer"), "manufacturer"),
        model=_str_or_none(data.get("model"), "model"),
        address=_str_or_none(data.get("address"), "address"),
        props=dict(props), selinux=selinux, max_patch_age_days=age, nfc=nfc,
        lock_screen_required=lock,
        settings=settings, manual_settings=manual,
        must_be_enabled=_packages((data.get("packages") or {}).get("mustBeEnabled") or [],
                                  "packages.mustBeEnabled"),
        flagged_permissions=list(flagged), must_be_installed=installed, managed=managed,
        digest=hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest())


def local_path() -> Path:
    base = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(base) / "android-iac" / "local.json"


def load(spec_path: Optional[str], local: Optional[str]) -> tuple[Spec, Optional[Path]]:
    """The spec, and the overlay's path when one was read. A missing overlay is not an error."""
    path = spec_path or os.environ.get("ANDROID_IAC_SPEC")
    if not path:
        raise SpecError("no spec: pass --spec or run the packaged `android-iac`")
    try:
        data = json.loads(Path(path).read_text())
        overlay = Path(local) if local else local_path()
        if local and not overlay.is_file():
            raise SpecError(f"no local overlay at {overlay}")
        extra = json.loads(overlay.read_text()) if overlay.is_file() else None
    except (OSError, json.JSONDecodeError) as e:
        raise SpecError(f"cannot read the spec: {e}") from e
    return parse(data, extra), (overlay if extra is not None else None)
