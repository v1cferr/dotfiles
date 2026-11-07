"""hypr-bench: A/B runs of the desktop's effects, changed only at runtime and always put back.

Every change goes through `hyprctl eval`, and `hyprctl reload config-only` (the repo's own config,
no modeset) undoes it: after a block, at the end, on a signal, and from a systemd dead-man timer
when this process dies without its `finally`. The why and the protocol: docs/notes/desktop/performance.md
"""
import argparse
import json
import os
import signal
import subprocess
import sys
import time

import metrics
import report

from safety import ACTIVE, CLASS, STATE, dispatch, guard, hypr_json, options, restore, sh

SELF = os.environ.get("HYPR_BENCH_SELF", os.path.realpath(sys.argv[0]))  # the wrapper
GLASS_OFF = "hl.plugin.hyprglass.config({ enabled = false, layers = { enabled = false } })"
SHELL_BLUR = ('hl.layer_rule({ match = { namespace = "^qs-(bar|dash|panel|center)$" },'
              ' blur = true, ignore_alpha = 0.5 })')
SCENARIOS = {
    "A": ("baseline", []),
    "B": ("no animation", ["hl.config({ animations = { enabled = false } })"]),
    "C": ("no blur", ["hl.config({ decoration = { blur = { enabled = false } } })", GLASS_OFF]),
    "D": ("minimal", ["hl.config({ animations = { enabled = false },"
                      " decoration = { blur = { enabled = false } } })", GLASS_OFF]),
    "E": ("native blur, no HyprGlass", [GLASS_OFF, SHELL_BLUR]),
}


def setup(args, run_dir):
    """Record what to restore, arm the dead-man, open the bench workspaces with static windows."""
    mons = hypr_json("monitors")
    focused = [m["activeWorkspace"]["name"] for m in mons if m["focused"]]
    state = {"options": options(), "run_dir": run_dir, "shell_hidden": args.shell_off,
             "workspaces": [m["activeWorkspace"]["name"] for m in mons if not m["focused"]] + focused}
    theme = json.load(open(os.path.expanduser("~/.config/theme/monitors.json")))
    primary, side = theme["primary"], theme["secondary"]
    block = len(args.workloads) * (args.settle + 4) + args.idle + args.short * len(args.workloads)
    budget = int(args.rounds * len(args.scenarios) * (block + 5))
    unit = f"hypr-bench-restore-{os.getpid()}"
    sh("systemd-run", "--user", f"--unit={unit}", f"--on-active={budget + 180}",
       SELF, "restore", check=True)
    state["deadman"] = unit
    os.makedirs(STATE, exist_ok=True)
    json.dump(state, open(ACTIVE, "w"))
    for ws, mon in (("bench-a", primary), ("bench-b", primary), ("bench-c", side)):
        sh("hyprctl", "eval", f'hl.workspace_rule({{ workspace = "name:{ws}", monitor = "{mon}" }})')
    term = os.environ.get("HYPR_BENCH_TERM", "kitty")
    for ws, n in (("bench-c", 1), ("bench-b", 1), ("bench-a", 2)):
        for _ in range(n):
            dispatch(f'hl.dsp.exec_cmd("{term} --class {CLASS} sleep infinity",'
                     f' {{ workspace = "name:{ws} silent" }})')
    time.sleep(3)
    placed = sorted(c["workspace"]["name"] for c in hypr_json("clients") if c["class"] == CLASS)
    if placed != ["bench-a", "bench-a", "bench-b", "bench-c"]:
        raise RuntimeError(f"the bench windows did not land where asked: {placed}")
    for ws in ("bench-c", "bench-a"):
        dispatch(f'hl.dsp.focus({{ workspace = "name:{ws}" }})')
    return state


def workload(kind, seconds, stop):
    """Drive one workload for `seconds`; True when the cursor moved (a human touched the desk)."""
    cursor = sh("hyprctl", "cursorpos")
    proc = None
    if kind == "fullscreen":
        proc = subprocess.Popen(["vkcube", "--wsi", "wayland", "--present_mode", "2"], stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL)
        time.sleep(1.5)
        dispatch('hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set" })')
    end, flip = time.monotonic() + seconds, False
    while time.monotonic() < end and not stop():
        flip = not flip
        if kind == "workspace":
            dispatch(f'hl.dsp.focus({{ workspace = "name:bench-{"b" if flip else "a"}" }})')
        elif kind == "window":
            win = [c for c in hypr_json("clients") if c["class"] == CLASS][-1]
            dispatch(f'hl.dsp.window.move({{ workspace = "name:bench-{"b" if flip else "a"}",'
                     f' window = "address:{win["address"]}", follow = false }})')
        elif kind == "panel":
            sh("qs", "ipc", "call", "bar", *(("panel", "weather") if flip else ("close",)))
        time.sleep(0.5 if kind in ("workspace", "window") else 1.0)
    if proc:
        proc.terminate()
        proc.wait(timeout=10)
    if kind == "workspace":
        dispatch('hl.dsp.focus({ workspace = "name:bench-a" })')
    if kind == "panel":
        sh("qs", "ipc", "call", "bar", "close")
    return sh("hyprctl", "cursorpos") != cursor


def run(args):
    profile = sh("powerprofilesctl", "get").strip()
    if (why := guard(profile)):
        sys.exit(f"hypr-bench: not starting, {why}")
    quiet = metrics.rates(metrics.snapshot(), (time.sleep(3), metrics.snapshot())[1])
    if (quiet.get("gpu_busy_pct") or 0) > args.max_busy:
        sys.exit(f"hypr-bench: not starting, the GPU is {quiet['gpu_busy_pct']:.0f}% busy before"
                 " any test (a game or a video?); close it, or raise --max-busy")
    run_dir = os.path.join(STATE, time.strftime("%Y%m%d-%H%M%S"))
    os.makedirs(run_dir)
    private = metrics.sudo_reader() if args.privileged else None
    stopping = []
    signal.signal(signal.SIGTERM, lambda *_: stopping.append(1))
    signal.signal(signal.SIGINT, lambda *_: stopping.append(1))
    env = report.environment(profile)
    state, rows = None, []
    try:
        state = setup(args, run_dir)
        for rnd in range(args.rounds):
            order = args.scenarios[rnd % len(args.scenarios):] + args.scenarios[:rnd % len(args.scenarios)]
            for sc in order:
                sh("hyprctl", "reload", "config-only")
                for lua in SCENARIOS[sc][1]:
                    sh("hyprctl", "eval", lua, check=True)
                if args.shell_off:
                    sh("qs", "ipc", "call", "bar", "hide")
                for kind in args.workloads:
                    if stopping:
                        raise KeyboardInterrupt
                    time.sleep(args.settle)
                    why = guard(profile)
                    a = metrics.snapshot(private)
                    touched = workload(kind, args.idle if kind == "idle" else args.short,
                                       lambda: bool(stopping))
                    b = metrics.snapshot(private)
                    row = {"round": rnd, "scenario": sc, "workload": kind,
                           "invalid": why or ("input during the block" if touched else None)}
                    rows.append(row | metrics.rates(a, b))
                    print(f"[{rnd}] {sc} {kind:10} " + report.brief(rows[-1]), flush=True)
    except KeyboardInterrupt:
        print("hypr-bench: interrupted, restoring", file=sys.stderr)
    finally:
        try:
            restore(state)  # the desk first; it exits non-zero when an option did not come back
        finally:
            report.write(run_dir, env, rows, args)
    print(f"hypr-bench: results in {run_dir}")


def main():
    p = argparse.ArgumentParser(prog="hypr-bench")
    p.add_argument("command", choices=["run", "restore", "probe", "report"])
    p.add_argument("dir", nargs="?", help="report: a run directory")
    p.add_argument("--rounds", type=int, default=3)
    p.add_argument("--scenarios", default="ABCDE")
    p.add_argument("--workloads", default="idle,workspace,window,panel,fullscreen")
    p.add_argument("--idle", type=float, default=45)
    p.add_argument("--short", type=float, default=20)
    p.add_argument("--settle", type=float, default=5)
    p.add_argument("--max-busy", type=float, default=50, help="refuse above this GPU busy %%")
    p.add_argument("--quick", action="store_true", help="1 round of short blocks, to check it works")
    p.add_argument("--shell-off", action="store_true", help="also hide the bar and band (qs ipc)")
    p.add_argument("--privileged", action="store_true", help="also read root-only counters via sudo")
    args = p.parse_args()
    args.scenarios, args.workloads = list(args.scenarios), args.workloads.split(",")
    if args.quick:
        args.rounds, args.idle, args.short, args.settle = 1, 15, 8, 3
    if args.command == "restore":
        restore()
    elif args.command == "probe":
        print(json.dumps(metrics.rates(metrics.snapshot(), (time.sleep(2), metrics.snapshot())[1]),
                         indent=1, default=str))
    elif args.command == "report":
        report.rewrite(args.dir)
    elif os.path.exists(ACTIVE):
        sys.exit(f"hypr-bench: a run did not finish ({ACTIVE}); run `hypr-bench restore` first")
    elif not os.environ.get("HYPR_BENCH_INHIBITED"):
        # hypridle honours a logind idle inhibitor: no lock and no Eco profile mid-run, and the
        # inhibitor dies with this process, even on SIGKILL.
        os.environ["HYPR_BENCH_INHIBITED"] = "1"
        os.execvp("systemd-inhibit", ["systemd-inhibit", "--what=idle", "--who=hypr-bench",
                                      "--why=desktop benchmark", SELF,
                                      *sys.argv[1:]])
    else:
        run(args)


if __name__ == "__main__":
    main()
