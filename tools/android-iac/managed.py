"""The `managed` block: what phase 2 may change. Validated here so a write the tool must never
make cannot even be declared."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from adb import NAMESPACES, PACKAGE, PERMISSION, SETTING_KEY, WRITE_VALUE

# Never disabled, whatever the spec says: the phone, payments and the permission system itself.
PROTECTED = frozenset({
    "android", "com.android.nfc", "com.android.phone", "com.android.settings", "com.android.systemui",
    "com.android.vending", "com.google.android.gms", "com.google.android.gsf",
    "com.google.android.webview", "com.android.providers.telephony", "com.android.shell",
    "com.google.android.permissioncontroller", "com.android.permissioncontroller",
})


@dataclass(frozen=True)
class Managed:
    settings: dict[tuple[str, str], str] = field(default_factory=dict)
    packages_disabled: list[str] = field(default_factory=list)
    permissions_revoked: dict[str, list[str]] = field(default_factory=dict)

    def __bool__(self) -> bool:
        return bool(self.settings or self.packages_disabled or self.permissions_revoked)


def parse(raw: Any, declared: set[tuple[str, str]], must_be_enabled: list[str]) -> Managed:
    """Raises ValueError with the path of the offending item."""
    if raw is None:
        return Managed()
    if not isinstance(raw, dict) or set(raw) - {"settings", "packagesDisabled", "permissionsRevoked"}:
        raise ValueError("expected settings, packagesDisabled and permissionsRevoked only")
    settings: dict[tuple[str, str], str] = {}
    for ns, keys in (raw.get("settings") or {}).items():
        if ns not in NAMESPACES or not isinstance(keys, dict):
            raise ValueError(f"settings.{ns}: unknown namespace")
        for key, value in keys.items():
            where = f"settings.{ns}.{key}"
            if not SETTING_KEY.match(key):
                raise ValueError(f"{where}: not a valid settings key")
            if not isinstance(value, str) or not WRITE_VALUE.match(value):
                raise ValueError(f"{where}: a managed value is a number or a package name")
            if (ns, key) in declared:
                raise ValueError(f"{where}: also audited or manual; a key has one policy")
            settings[(ns, key)] = value
    disabled = raw.get("packagesDisabled") or []
    if not isinstance(disabled, list) or not all(isinstance(p, str) and PACKAGE.match(p) for p in disabled):
        raise ValueError("packagesDisabled: expected a list of package names")
    forbidden = sorted(set(disabled) & (PROTECTED | set(must_be_enabled)))
    if forbidden:
        raise ValueError(f"packagesDisabled: never disabled: {', '.join(forbidden)}")
    revoked: dict[str, list[str]] = {}
    for pkg, perms in (raw.get("permissionsRevoked") or {}).items():
        if not PACKAGE.match(pkg) or not isinstance(perms, list) or not all(
                isinstance(p, str) and PERMISSION.match(p) for p in perms):
            raise ValueError(f"permissionsRevoked.{pkg}: a package name to a list of android.permission.*")
        revoked[pkg] = list(perms)
    return Managed(settings, list(disabled), revoked)
