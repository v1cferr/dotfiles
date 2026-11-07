"""Declared against observed. No evidence is UNKNOWN, never in sync."""

from __future__ import annotations

import datetime as dt
from dataclasses import asdict, dataclass
from enum import Enum
from typing import Any, Optional

import sanitize
from spec import Spec
from state import Observed


class Status(str, Enum):
    IN_SYNC = "in-sync"
    DRIFT = "drift"
    UNSUPPORTED = "unsupported"
    UNKNOWN = "unknown"
    MANUAL = "manual"


@dataclass(frozen=True)
class Finding:
    status: Status
    check: str
    observed: Optional[str]
    expected: Optional[str]
    note: str = ""

    def as_dict(self) -> dict[str, Any]:
        return dict(sanitize.deep_scrub({**asdict(self), "status": self.status.value}))


def _eq(check: str, got: Optional[str], want: Optional[str], note: str = "") -> Finding:
    if got is None:
        return Finding(Status.UNKNOWN, check, None, want, note or "the device did not answer")
    return Finding(Status.IN_SYNC if got == want else Status.DRIFT, check, got, want, note)


def _patch(spec: Spec, o: Observed, today: dt.date) -> list[Finding]:
    if spec.max_patch_age_days is None:
        return []
    raw = o.props.get("ro.build.version.security_patch")
    want = f"<= {spec.max_patch_age_days} days old"
    try:
        age = (today - dt.date.fromisoformat(raw or "")).days
    except ValueError:
        return [Finding(Status.UNKNOWN, "security patch", raw, want, "unreadable patch level")]
    ok = age <= spec.max_patch_age_days
    return [Finding(Status.IN_SYNC if ok else Status.DRIFT, "security patch", f"{raw} ({age} days)", want,
                    "" if ok else "install the pending system update (Settings, System, Software update)")]


def _settings(spec: Spec, o: Observed) -> list[Finding]:
    out = []
    for (ns, key), want in sorted(spec.settings.items()):
        check = f"setting {ns}.{key}"
        if (ns, key) not in o.settings:
            out.append(Finding(Status.UNKNOWN, check, None, want, "the read failed"))
            continue
        got = o.settings[(ns, key)]
        shown = sanitize.setting_value(key, got)
        if want is None:
            out.append(Finding(Status.IN_SYNC if got is None else Status.DRIFT, check, shown, None))
        elif got is None:
            out.append(Finding(Status.UNKNOWN, check, None, want, "unset: the default applies, and it is not readable"))
        else:
            out.append(Finding(Status.IN_SYNC if got == want else Status.DRIFT, check, shown, want))
    for (ns, key), want in sorted(spec.manual_settings.items()):
        check = f"setting {ns}.{key}"
        got = o.settings.get((ns, key))
        if (ns, key) not in o.settings:
            out.append(Finding(Status.UNKNOWN, check, None, want, "the read failed"))
        elif got == want or (got is None and want in (None, "0")):
            out.append(Finding(Status.IN_SYNC, check, got, want))
        else:
            out.append(Finding(Status.MANUAL, check, sanitize.setting_value(key, got), want,
                               "turn it off on the phone once the audit is done"))
    return out


def _packages(spec: Spec, o: Observed) -> list[Finding]:
    out = []
    if o.installed is None or o.enabled is None:
        return [Finding(Status.UNKNOWN, f"package {p}", None, "enabled", "the package list failed")
                for p in [*spec.must_be_enabled, *spec.must_be_installed]]
    for pkg in spec.must_be_enabled:
        if pkg not in o.installed:
            out.append(Finding(Status.UNSUPPORTED, f"package {pkg}", "absent", "enabled",
                               "not on this build: drop it from the spec or name the vendor's package"))
        else:
            out.append(Finding(Status.IN_SYNC if pkg in o.enabled else Status.DRIFT, f"package {pkg}",
                               "enabled" if pkg in o.enabled else "disabled", "enabled"))
    for pkg in spec.must_be_installed:
        got = "absent" if pkg not in o.installed else "enabled" if pkg in o.enabled else "disabled"
        out.append(Finding(Status.IN_SYNC if got == "enabled" else Status.DRIFT, f"app {pkg} (local)", got,
                           "enabled", "" if got == "enabled" else "install or enable it from the Play Store"))
    return out


def findings(spec: Spec, o: Observed, today: Optional[dt.date] = None) -> list[Finding]:
    out = [_eq(f"prop {k}", o.props.get(k), v) for k, v in sorted(spec.props.items())]
    if spec.selinux is not None:
        out.append(_eq("selinux", o.selinux, spec.selinux))
    if spec.nfc is not None:
        out.append(_eq("nfc", o.nfc, spec.nfc))
    if spec.lock_screen_required:
        if o.lock_disabled is None:
            out.append(Finding(Status.UNKNOWN, "lock screen", None, "secure", "the device did not answer"))
        elif o.lock_disabled:
            out.append(Finding(Status.DRIFT, "lock screen", "disabled", "secure", "set a PIN, pattern or password"))
        else:
            out.append(Finding(Status.MANUAL, "lock screen", "not disabled", "secure",
                               "a swipe lock reads the same: confirm a PIN or password by eye"))
    out += _patch(spec, o, today or dt.date.today())
    out += _settings(spec, o)
    out += _packages(spec, o)
    if o.permissions is not None:
        for pkg, perms in sorted(o.permissions.items()):
            for perm in sorted(perms & set(spec.flagged_permissions)):
                out.append(Finding(Status.MANUAL, f"permission {pkg}", perm.rsplit(".", 1)[-1], None,
                                   "review: does this app need it?"))
    return out


def exit_code(fs: list[Finding]) -> int:
    """0 in sync, 1 drift, 3 nothing drifted but some evidence is missing or needs a person."""
    statuses = {f.status for f in fs}
    if Status.DRIFT in statuses:
        return 1
    if statuses & {Status.UNKNOWN, Status.MANUAL, Status.UNSUPPORTED}:
        return 3
    return 0
