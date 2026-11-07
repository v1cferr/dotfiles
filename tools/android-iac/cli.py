"""android-iac: observe an Android phone over ADB and compare it with its declaration. Read-only."""

from __future__ import annotations

import argparse
import getpass
import json
import os
import sys
from typing import Any, Optional, Sequence

import compare
import plan
import session
import state
from adb import Adb, AdbError, NoDevice, Runner, subprocess_runner
from doctor import doctor
from spec import Spec, SpecError, load

ENV_ERROR = 2
ORDER = [compare.Status.DRIFT, compare.Status.MANUAL, compare.Status.UNKNOWN,
         compare.Status.UNSUPPORTED, compare.Status.IN_SYNC]


def _table(fs: list[compare.Finding], only_problems: bool) -> str:
    rows = [f for s in ORDER for f in fs if f.status is s and not (only_problems and s is compare.Status.IN_SYNC)]
    lines = []
    for f in rows:
        d = f.as_dict()
        exp = "unset" if f.expected is None else d["expected"]
        obs = "unset" if f.observed is None and f.status is not compare.Status.UNKNOWN else d["observed"] or "?"
        lines.append(f"{f.status.value:<12} {d['check']:<52} {obs} (want {exp})" + (f"  {d['note']}" if f.note else ""))
    return "\n".join(lines)


def _summary(fs: list[compare.Finding]) -> str:
    counts = {s: sum(f.status is s for f in fs) for s in ORDER}
    return ", ".join(f"{n} {s.value}" for s, n in counts.items() if n)


def main(argv: Optional[Sequence[str]] = None, runner: Optional[Runner] = None) -> int:
    ap = argparse.ArgumentParser(prog="android-iac", description=__doc__)
    ap.add_argument("--spec", help="the declared state as JSON (default: the packaged host spec)")
    ap.add_argument("--local", help="the private overlay (default: $XDG_CONFIG_HOME/android-iac/local.json)")
    ap.add_argument("--transport-id", help="which device, when several are attached (see doctor)")
    sub = ap.add_subparsers(dest="command", required=True)
    sub.add_parser("doctor", help="check adb, the connection, the authorization and the spec")
    sub.add_parser("audit", help="the whole session in one go: connect (pairing if needed), doctor, "
                   "inspect, diff, disconnect")
    ins = sub.add_parser("inspect", help="a sanitized report of the device")
    ins.add_argument("--json", action="store_true")
    for name, text in (("diff", "every declared check, against the device"),
                       ("verify", "only what is not in sync, and an exit code for scripts")):
        p = sub.add_parser(name, help=text)
        p.add_argument("--json", action="store_true")
    pl = sub.add_parser("plan", help="the changes that would bring the managed items in line; saved, never run")
    pl.add_argument("--json", action="store_true")
    for p in (ins, *[sub.choices[n] for n in ("diff", "verify")]):
        p.add_argument("--permissions", action="store_true",
                       help="also read each third-party app's granted permissions (slower)")
    args = ap.parse_args(argv)

    target = ["-t", args.transport_id] if args.transport_id else []
    adb = Adb(runner or subprocess_runner(target))
    if args.command == "doctor":
        return doctor(adb, args.spec, args.local, args.transport_id)
    try:
        spec, overlay = load(args.spec, args.local)
    except SpecError as e:
        print(f"android-iac: spec: {e}", file=sys.stderr)
        return ENV_ERROR
    if args.command == "audit":
        return audit(adb, spec, (args.spec, args.local), overlay is not None, args.transport_id, runner)
    try:
        state.select(adb, args.transport_id, "ANDROID_SERIAL" in os.environ)
        observed = state.observe(adb, spec, getattr(args, "permissions", False))
        if args.command == "plan":
            return plan.run(spec, observed, args.json)
        if args.command == "inspect":
            report = state.report(adb, observed)
            if args.json:
                print(json.dumps(report, indent=2, sort_keys=True))
            else:
                _print_inspect(report)
            return 0
    except AdbError as e:
        print(f"android-iac: {e}", file=sys.stderr)
        return ENV_ERROR
    return _compare(spec, observed, overlay is not None, args.command == "verify", args.json)


def _ask(prompt: str, secret: bool) -> str:
    return getpass.getpass(prompt) if secret else input(prompt)


def audit(adb: Adb, spec: Spec, paths: tuple[Optional[str], Optional[str]], has_overlay: bool, transport_id: Optional[str],
          runner: Optional[Runner], ask: session.Ask = _ask, browse: session.Browse = session.avahi_browse) -> int:
    """One command for a whole session. A device already attached is used and left attached."""
    endpoint = None
    try:
        try:
            state.select(adb, transport_id, "ANDROID_SERIAL" in os.environ)
            target = adb
        except NoDevice:
            if spec.address is None:
                raise
            endpoint = session.open_session(adb, spec.address, ask, browse)
            target = Adb(runner or subprocess_runner(["-s", endpoint]))
        print("== doctor ==")
        if doctor(target, *paths, None) == 2:
            return ENV_ERROR
        observed = state.observe(target, spec)
        print("\n== inspect ==")
        _print_inspect(state.report(target, observed))
        print("\n== diff ==")
        return _compare(spec, observed, has_overlay, False, False)
    except AdbError as e:
        print(f"android-iac: {e}", file=sys.stderr)
        return ENV_ERROR
    finally:
        session.close_session(adb, endpoint)


def _compare(spec: Spec, observed: state.Observed, has_overlay: bool, only_problems: bool, as_json: bool) -> int:
    fs = compare.findings(spec, observed)
    code = compare.exit_code(fs)
    if as_json:
        print(json.dumps({"spec": spec.name, "exit": code, "findings": [f.as_dict() for f in fs]}, indent=2))
        return code
    print(_table(fs, only_problems) or "everything declared is in sync")
    print(f"\n{spec.name}: {_summary(fs)}")
    if not has_overlay:
        print("no local overlay: private apps were not checked (see `android-iac doctor`)")
    return code


def _print_inspect(r: dict[str, Any]) -> None:
    for section in ("device", "boot"):
        print(f"[{section}]")
        for k, v in r[section].items():
            print(f"  {k:<18} {v}")
    print(f"[security]\n  {'nfc':<18} {r['nfc']}\n  {'lockScreenDisabled':<18} {r['lockScreenDisabled']}")
    pk = r["packages"]
    print("[packages]")
    for k, v in pk.items():
        print(f"  {k:<18} {'unknown' if v is None else len(v)}")
    print("\nThe full report, settings and package names included: `android-iac inspect --json`.")
    print("It is personal: keep it out of the repo.")


def run() -> int:
    """The entry point: Ctrl-C ends with the shell's 130, not a traceback."""
    try:
        return main()
    except KeyboardInterrupt:
        print("\ninterrupted", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(run())
