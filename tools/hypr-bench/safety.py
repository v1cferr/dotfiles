"""The parts that keep the desk safe: hyprctl helpers, the guards, and the one restore path.

`hyprctl reload config-only` re-runs the repo's config without a modeset, so it undoes every
`hyprctl eval` of a scenario; the rest of restore() puts back what the run itself opened.
"""
import json
import os
import signal
import subprocess
import sys
import time

STATE = os.path.expanduser("~/.local/state/hypr-bench")
ACTIVE = os.path.join(STATE, "active.json")
CLASS = "hypr-bench"
KEYS = ["animations:enabled", "decoration:blur:enabled", "plugin:hyprglass:enabled"]


def sh(*cmd, check=False):
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    if check and out.returncode != 0:
        sys.exit(f"hypr-bench: {' '.join(cmd)} failed: {out.stderr.strip()}")
    return out.stdout


def hypr_json(what):
    return json.loads(sh("hyprctl", "-j", what) or "null")


def dispatch(lua):
    sh("hyprctl", "dispatch", lua)


def options():
    return {k: json.loads(sh("hyprctl", "getoption", k, "-j") or "{}").get("bool") for k in KEYS}


def guard(start_profile):
    """Why this moment must not be measured, or None."""
    if sh("systemctl", "--user", "is-active", "lockscreen.service").strip() == "active":
        return "the session is locked"
    if any(c["fullscreen"] > 0 and c["class"] != CLASS for c in hypr_json("clients")):
        return "a window of yours is fullscreen"
    if any(f":{p} " in sh("ss", "-Huan") for p in (47998, 47999, 48000)):
        return "a Sunshine stream is live"
    if start_profile and sh("powerprofilesctl", "get").strip() != start_profile:
        return "the power profile changed"
    return None


def restore(state=None):
    """Put everything back; safe to run twice, and from the dead-man with no state at all."""
    state = state or (json.load(open(ACTIVE)) if os.path.exists(ACTIVE) else {})
    sh("hyprctl", "reload", "config-only")
    sh("qs", "ipc", "call", "bar", "close")
    if state.get("shell_hidden"):
        sh("qs", "ipc", "call", "bar", "unhide")
    for c in hypr_json("clients") or []:
        if c["class"] in (CLASS, "vkcube"):
            os.kill(c["pid"], signal.SIGTERM)
    for ws in state.get("workspaces", []):
        dispatch(f'hl.dsp.focus({{ workspace = "{ws}" }})')
    time.sleep(1)
    bad = {k: v for k, v in options().items() if state.get("options", {}).get(k, v) != v}
    if os.path.exists(ACTIVE):
        os.remove(ACTIVE)
    if state.get("deadman"):
        sh("systemctl", "--user", "stop", state["deadman"] + ".timer")
    if bad:
        sys.exit(f"hypr-bench: NOT restored, options differ from the start: {bad}")
    print("hypr-bench: restored (" + ", ".join(f"{k}={v}" for k, v in options().items()) + ")")
