"""`android-iac apply --dry-run`: rehearse a saved plan against a fresh read; nothing runs on the
phone. The commands are rebuilt from that read, never taken from the plan file."""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import shlex
import sys
from pathlib import Path
from typing import Any, Optional

import plan
import sanitize
from spec import Spec
from state import Observed


class PlanError(Exception):
    """No plan, or a file that is not one."""


def latest() -> Path:
    found = sorted((plan.state_dir() / "plans").glob("*.json"))
    if not found:
        raise PlanError("no saved plan: run `android-iac plan` first")
    return found[-1]


def load(path: Path) -> tuple[dict[str, Any], str]:
    """The plan and the sha256 of its bytes, which ties a rehearsal to exactly this file."""
    try:
        raw = path.read_bytes()
        doc = json.loads(raw)
    except (OSError, ValueError) as e:
        raise PlanError(f"{path}: {e}") from e
    if not isinstance(doc, dict) or doc.get("version") != 1 or not isinstance(doc.get("ops"), list) \
            or not all(isinstance(op, dict) for op in doc["ops"]):
        raise PlanError(f"{path}: not an android-iac plan")
    return doc, hashlib.sha256(raw).hexdigest()


def stale(spec: Spec, o: Observed, doc: dict[str, Any]) -> tuple[list[str], list[plan.Op]]:
    """Why the plan no longer fits the declaration or the phone (empty when it does), and the ops."""
    why = []
    if doc.get("spec") != spec.name or doc.get("specDigest") != spec.digest:
        why.append("the declaration changed since the plan")
    if doc.get("fingerprint") != o.props.get("ro.build.fingerprint"):
        why.append("the phone's build changed since the plan (a system update?)")
    found = plan.checks(spec, o)
    why += [f"{c.op.target}: blocked, {c.note}" for c in found if c.state == "blocked"]
    ops = [c.op for c in found if c.state == "change"]
    now = {(op.kind, op.target, op.before, op.after) for op in ops}
    planned = {(op.get("kind"), op.get("target"), op.get("before"), op.get("after")) for op in doc["ops"]}
    why += [f"{t[1]}: planned {t[2] or 'unset'} -> {t[3]}, not what the phone needs now"
            for t in sorted(planned - now, key=str)]
    why += [f"{t[1]}: needs a change the plan does not hold" for t in sorted(now - planned, key=str)]
    return why, ops


def rehearse(path: Path, sha: str, now: dt.datetime) -> Path:
    """The mark `apply` (phase 2c) will require: this plan's bytes, rehearsed at this time."""
    folder = plan.state_dir() / "rehearsals"
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    out = folder / path.name
    fd = os.open(out, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump({"plan": str(path), "planSha256": sha, "rehearsed": now.isoformat(timespec="seconds")}, f, indent=2)
    return out


def dry_run(spec: Spec, o: Observed, path: Optional[str], as_json: bool) -> int:
    """0 rehearsed, 1 refused (make a fresh plan), 2 no usable plan."""
    try:
        p = Path(path) if path else latest()
        doc, sha = load(p)
    except PlanError as e:
        print(f"android-iac: {e}", file=sys.stderr)
        return 2
    why, ops = stale(spec, o, doc)
    mark = None if why else rehearse(p, sha, dt.datetime.now().astimezone())
    commands = [{"argv": op.argv(), "undo": op.undo(), "sensitive": op.sensitive} for op in ops]
    if as_json:
        print(json.dumps(sanitize.deep_scrub({"plan": str(p), "rehearsed": str(mark) if mark else None,
                                              "refused": why, "commands": [] if why else commands}), indent=2))
        return 1 if why else 0
    print(f"plan: {p}")
    for reason in why:
        print(f"refused      {reason}")
    if why:
        print("not rehearsed: the phone or the declaration moved; make a fresh one with `android-iac plan`")
        return 1
    for op in ops:
        flag = "  sensitive: apply will ask to type it" if op.sensitive else ""
        print(f"would run    adb {shlex.join(op.argv())}{flag}\n  undo       adb {shlex.join(op.undo())}")
    print(f"\nrehearsed: {len(ops)} operations, nothing was run ({mark})")
    return 0
