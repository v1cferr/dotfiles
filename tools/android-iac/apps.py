"""`android-iac apps`: the phone's enabled third-party apps as the local overlay's `mustBeInstalled`.
Printed, or written with --save to the overlay (owner-only, never in the repo); reads only."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Optional

import spec
from state import Observed


def run(o: Observed, save: bool, local: Optional[str]) -> int:
    """0 done, 2 the package lists could not be read or the overlay is not a JSON object."""
    if o.third_party is None or o.enabled is None:
        print("android-iac: the package lists could not be read", file=sys.stderr)
        return 2
    apps = sorted(o.third_party & o.enabled)
    left_out = len(o.third_party - o.enabled)
    if not save:
        print(json.dumps({"mustBeInstalled": apps}, indent=2))
        return 0
    path = Path(local) if local else spec.local_path()
    current = json.loads(path.read_text()) if path.is_file() else {}
    if not isinstance(current, dict):
        print(f"android-iac: {path} is not a JSON object", file=sys.stderr)
        return 2
    before = set(current.get("mustBeInstalled") or [])
    current["mustBeInstalled"] = apps  # the other keys of the overlay are kept
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    tmp = path.with_name(path.name + ".tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(current, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)
    print(f"saved {len(apps)} apps to {path} ({len(set(apps) - before)} new, {len(before - set(apps))} gone)")
    if left_out:
        print(f"{left_out} disabled third-party apps were left out: `android-iac apps` lists only enabled ones")
    return 0
