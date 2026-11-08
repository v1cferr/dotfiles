"""`android-iac apply` and `rollback`: the only code that changes the phone. One operation at a
time, each verified by a fresh read and journaled before the next; the first failure stops it."""

from __future__ import annotations

import datetime as dt
import json
import os
import sys
from pathlib import Path
from typing import Any, Callable, Optional, TextIO

import apply
import parse
import plan
from adb import Adb, AdbError
from spec import Spec
from state import Observed

REHEARSAL_TTL = dt.timedelta(minutes=10)
UNREAD = "?"  # never a value: WRITE_VALUE refuses `?`, so it cannot collide with a real one
Ask = Callable[[str], str]


def current(adb: Adb, op: plan.Op) -> Optional[str]:
    """The target as the phone reads it now, in the op's own words (`before` and `after`)."""
    if op.kind == "settings-put":
        out = adb.try_call("shell", "settings", "get", *op.target.split(".", 1))
        return UNREAD if out is None else parse.setting(out)
    if op.kind == "pm-disable":
        out = adb.try_call("shell", "pm", "list", "packages", "-d")
        return UNREAD if out is None else "disabled" if op.target in parse.packages(out) else "enabled"
    pkg, perm = op.target.split(" ", 1)
    out = adb.try_call("shell", "dumpsys", "package", pkg)
    return UNREAD if out is None else "granted" if perm in parse.granted_runtime(out) else "revoked"


def _journal(name: str) -> TextIO:
    folder = plan.state_dir() / "journal"
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd = os.open(folder / name, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    return os.fdopen(fd, "a")


def _log(f: TextIO, action: str, op: plan.Op, result: str, note: str = "") -> None:
    entry = {"time": dt.datetime.now().astimezone().isoformat(timespec="seconds"), "action": action,
             "kind": op.kind, "target": op.target, "before": op.before, "after": op.after,
             "result": result, "note": note}
    f.write(json.dumps(entry) + "\n")
    f.flush()
    os.fsync(f.fileno())


def _rehearsed(path: Path, sha: str, now: dt.datetime) -> Optional[str]:
    """Why this plan may not run yet, or None when its rehearsal is fresh and of these bytes."""
    try:
        mark = json.loads((plan.state_dir() / "rehearsals" / path.name).read_text())
        when = dt.datetime.fromisoformat(mark["rehearsed"])
    except (OSError, ValueError, KeyError, TypeError):
        return "not rehearsed: run `android-iac apply --dry-run` first"
    if mark.get("planSha256") != sha:
        return "the plan changed since its rehearsal: rehearse it again"
    if now - when > REHEARSAL_TTL:
        return "the rehearsal is older than 10 minutes: rehearse it again"
    return None


def _run(adb: Adb, f: TextIO, action: str, op: plan.Op, argv: list[str], want: Optional[str]) -> str:
    """ok; refused (the phone said no and a re-read proves nothing moved: safe to go on); or failed."""
    was = op.before if action == "apply" else op.after
    try:
        adb.write(*argv)
    except AdbError as e:
        reason = str(e).rsplit("failed: ", 1)[-1]
        if current(adb, op) == was:
            _log(f, action, op, "refused", reason)
            print(f"  REFUSED  {op.describe()}: {reason} (unchanged)")
            return "refused"
        _log(f, action, op, "failed", reason)
        print(f"  FAILED   {op.describe()}: {reason}")
        return "failed"
    got = current(adb, op)
    if got != want:
        _log(f, action, op, "unverified", f"reads {got}")
        print(f"  FAILED   {op.describe()}: unverified, reads {got or 'unset'}, want {want or 'unset'}")
        return "failed"
    _log(f, action, op, "ok")
    print(f"  ok       {op.describe() if action == 'apply' else 'undone: ' + op.describe()}")
    return "ok"


def run_apply(spec: Spec, o: Observed, adb: Adb, path: Optional[str], ask: Ask) -> int:
    """0 applied, 1 not run, stopped, or some refused by the phone (the journal says which), 2 no plan."""
    now = dt.datetime.now().astimezone()
    try:
        p = Path(path) if path else apply.latest()
        doc, sha = apply.load(p)
    except apply.PlanError as e:
        print(f"android-iac: {e}", file=sys.stderr)
        return 2
    why, ops = apply.stale(spec, o, doc)
    not_ready = _rehearsed(p, sha, now)
    for reason in [*why, *([not_ready] if not_ready else [])]:
        print(f"refused: {reason}")
    if why or not_ready:
        return 1
    print("apply will:")
    for op in ops:
        print(f"  {op.describe()}")
    if ask(f'\n{plan.tally(ops)}. Type "apply" to run it on the phone: ').strip() != "apply":
        print("nothing was run")
        return 1
    for op in (op for op in ops if op.sensitive):
        if ask(f"{op.target} is sensitive; type it to confirm: ").strip() != op.target:
            print("nothing was run")
            return 1
    name = f"{now.strftime('%Y%m%d-%H%M%S')}.jsonl"
    refused = []
    with _journal(name) as f:
        for op in ops:
            result = _run(adb, f, "apply", op, op.argv(), op.after)
            if result == "failed":
                print(f"\nstopped; what ran is in the journal: android-iac rollback {name}")
                return 1
            if result == "refused":
                refused.append(op)
    (plan.state_dir() / "rehearsals" / p.name).unlink(missing_ok=True)  # a plan runs once
    done = [op for op in ops if op not in refused]
    print(f"\napplied: {plan.tally(done)}.\nundo: android-iac rollback {name}")
    if refused:
        print(f"refused by the phone, so drop them from the host's `managed` block: "
              f"{', '.join(op.target for op in refused)}")
    return 1 if refused else 0


def _applied(lines: list[dict[str, Any]]) -> list[plan.Op]:
    """The operations apply completed and no rollback has undone yet, newest first."""
    undone = {e["target"] for e in lines if e.get("action") == "rollback" and e.get("result") == "ok"}
    ops = [plan.Op(e["kind"], e["target"], e["before"], e["after"]) for e in lines
           if e.get("action") == "apply" and e.get("result") == "ok" and e["target"] not in undone]
    return ops[::-1]


def run_rollback(adb: Adb, name: Optional[str], ask: Ask) -> int:
    """0 undone (or nothing left to undo), 1 stopped or some skipped, 2 no usable journal."""
    folder = plan.state_dir() / "journal"
    found = sorted(folder.glob("*.jsonl")) if folder.is_dir() else []
    path = folder / name if name and "/" not in name else Path(name) if name else (found[-1] if found else None)
    try:
        lines = [json.loads(x) for x in path.read_text().splitlines() if x.strip()] if path else None
    except (OSError, ValueError) as e:
        lines, path = None, None
        print(f"android-iac: {e}", file=sys.stderr)
    if not path or lines is None or not all(isinstance(e, dict) for e in lines):
        print("android-iac: no usable journal: `android-iac apply` writes one", file=sys.stderr)
        return 2
    ops = _applied(lines)
    if not ops:
        print(f"nothing to undo in {path.name}")
        return 0
    todo, skipped = [], 0
    for op in ops:
        got = current(adb, op)
        if got == op.after:
            todo.append(op)
            print(f"  undo     {op.describe()}")
        else:
            skipped += 1
            print(f"  skip     {op.describe()}: changed since apply (reads {got or 'unset'}), left as is")
    if todo and ask(f'\nType "rollback" to undo these {len(todo)} operations: ').strip() != "rollback":
        print("nothing was run")
        return 1
    with _journal(path.name) as f:
        for op in todo:
            if _run(adb, f, "rollback", op, op.undo(), op.before) != "ok":
                return 1
    print(f"\nundone: {len(todo)}, skipped: {skipped}")
    return 1 if skipped else 0
