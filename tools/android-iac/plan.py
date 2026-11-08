"""`android-iac plan`: the operations that would bring the phone to its managed declaration.
Read-only: it runs nothing on the phone, and only saves the plan under $XDG_STATE_HOME."""

from __future__ import annotations

import datetime as dt
import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Optional

import sanitize
from adb import allowed_write
from spec import Spec
from state import Observed

SENSITIVE_WORDS = ("wifi", "bluetooth", "nfc", "airplane", "location", "adb", "lock", "usb", "network", "data")


@dataclass(frozen=True)
class Op:
    kind: str  # settings-put | pm-disable | pm-revoke
    target: str  # ns.key | package | "package permission"
    before: Optional[str]
    after: str

    @property
    def sensitive(self) -> bool:
        if self.kind == "pm-revoke":
            return True
        return self.kind == "settings-put" and (
            self.target.startswith("secure.") or any(w in self.target for w in SENSITIVE_WORDS))

    def argv(self) -> list[str]:
        if self.kind == "settings-put":
            ns, key = self.target.split(".", 1)
            return ["shell", "settings", "put", ns, key, self.after]
        if self.kind == "pm-disable":
            return ["shell", "pm", "disable-user", "--user", "0", self.target]
        return ["shell", "pm", "revoke", *self.target.split(" ", 1)]

    def describe(self) -> str:
        """One line a person reads: the change in words, not adb's argv (`--verbose` shows that)."""
        if self.kind == "settings-put":
            line = f"set      {self.target}: {self.before or 'unset'} -> {self.after}"
        elif self.kind == "pm-disable":
            line = f"disable  {self.target}"
        else:
            pkg, perm = self.target.split(" ", 1)
            line = f"revoke   {perm.rsplit('.', 1)[-1]} from {pkg}"
        return line + ("  [sensitive]" if self.sensitive else "")

    def undo(self) -> list[str]:
        """The reverse, so reversibility is proven when planning, not hoped for when applying."""
        if self.kind == "settings-put":
            ns, key = self.target.split(".", 1)
            if self.before is None:
                return ["shell", "settings", "delete", ns, key]
            return ["shell", "settings", "put", ns, key, self.before]
        if self.kind == "pm-disable":
            return ["shell", "pm", "enable", "--user", "0", self.target]
        return ["shell", "pm", "grant", *self.target.split(" ", 1)]


def tally(ops: list[Op]) -> str:
    """`28 packages to disable, 1 setting to change`."""
    kinds = (("settings-put", "setting", "to change"), ("pm-disable", "package", "to disable"),
             ("pm-revoke", "permission", "to revoke"))
    parts = [f"{n} {noun}{'s' if n > 1 else ''} {verb}" for kind, noun, verb in kinds
             if (n := sum(op.kind == kind for op in ops))]
    return ", ".join(parts) or "nothing to change"


@dataclass(frozen=True)
class Check:
    op: Op
    state: str  # in-sync | change | blocked
    note: str = ""


def _change(op: Op) -> Check:
    if not allowed_write(op.argv()):
        return Check(op, "blocked", "not a writable shape")
    if not allowed_write(op.undo()):
        return Check(op, "blocked", "the current value could not be restored exactly")
    return Check(op, "change")


def checks(spec: Spec, o: Observed) -> list[Check]:
    out = []
    for (ns, key), want in sorted(spec.managed.settings.items()):
        op = Op("settings-put", f"{ns}.{key}", o.settings.get((ns, key)), want)
        if (ns, key) not in o.settings:
            out.append(Check(op, "blocked", "the read failed"))
        else:
            out.append(Check(op, "in-sync") if op.before == want else _change(op))
    for pkg in spec.managed.packages_disabled:
        op = Op("pm-disable", pkg, "enabled", "disabled")
        if o.installed is None or o.enabled is None or o.disabled is None:
            out.append(Check(op, "blocked", "the package lists failed"))
        elif pkg not in o.installed or pkg in o.disabled:
            out.append(Check(op, "in-sync", "" if pkg in o.installed else "not installed"))
        else:
            out.append(_change(op) if pkg in o.enabled else Check(op, "blocked", "neither enabled nor disabled"))
    for pkg, perms in sorted(spec.managed.permissions_revoked.items()):
        for perm in perms:
            op = Op("pm-revoke", f"{pkg} {perm}", "granted", "revoked")
            if o.installed is None:
                out.append(Check(op, "blocked", "the package list failed"))
            elif pkg not in o.installed:
                out.append(Check(op, "in-sync", "not installed"))
            elif pkg not in o.managed_permissions:
                out.append(Check(op, "blocked", "its permissions could not be read"))
            else:
                out.append(_change(op) if perm in o.managed_permissions[pkg] else Check(op, "in-sync"))
    return out


def document(spec: Spec, o: Observed, ops: list[Op], now: dt.datetime) -> dict[str, Any]:
    return dict(sanitize.deep_scrub({
        "version": 1, "spec": spec.name, "specDigest": spec.digest,
        "fingerprint": o.props.get("ro.build.fingerprint"), "created": now.isoformat(timespec="seconds"),
        "ops": [{"kind": op.kind, "target": op.target, "before": op.before, "after": op.after,
                 "sensitive": op.sensitive, "argv": op.argv(), "undo": op.undo()} for op in ops],
    }))


def state_dir() -> Path:
    base = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(base) / "android-iac"


def save(doc: dict[str, Any], now: dt.datetime) -> Path:
    """Owner-only, outside the repo: a plan names my apps when it touches their permissions."""
    folder = state_dir() / "plans"
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    path = folder / f"{now.strftime('%Y%m%d-%H%M%S')}.json"
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(doc, f, indent=2)
    return path


def run(spec: Spec, observed: Observed, as_json: bool) -> int:
    """0 nothing to change, 1 a plan was saved, 3 blocked by missing evidence (nothing saved)."""
    found = checks(spec, observed)
    blocked = [c for c in found if c.state == "blocked"]
    ops = [c.op for c in found if c.state == "change"]
    now = dt.datetime.now().astimezone()
    doc = document(spec, observed, ops, now)
    path = save(doc, now) if ops and not blocked else None
    if as_json:
        print(json.dumps({**doc, "saved": str(path) if path else None,
                          "blocked": [{"target": c.op.target, "note": c.note} for c in blocked]}, indent=2))
    else:
        if not spec.managed:
            print("nothing is managed: declare a `managed` block in the host file first")
        for c in blocked:
            print(f"  blocked  {c.op.target}: {c.note}")
        for op in ops:
            print(f"  {op.describe()}")
        print(f"\n{spec.name}: {tally(ops)} ({sum(c.state == 'in-sync' for c in found)} in sync, "
              f"{len(blocked)} blocked)")
        if path:
            print(f"saved {path.name}, nothing was run.\nnext: android-iac apply --dry-run")
        elif blocked:
            print("not saved: a plan with blocked items would be a guess")
    return 3 if blocked else 1 if ops else 0
