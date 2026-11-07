"""The run's context, its raw rows and the comparison tables (JSON, CSV and Markdown).

The aggregate is a mean over ROUNDS with its sample standard deviation; a block marked invalid
(lock, fullscreen, stream, profile change, a human at the desk) never enters it.
"""
import csv
import json
import os
import platform
import statistics
import subprocess

# The columns the Markdown shows, in order; the CSV and JSON keep every metric.
COLUMNS = [
    ("hyprland_cpu_pct", "Hyprland CPU %"), ("quickshell_cpu_pct", "Quickshell CPU %"),
    ("cpu_all_pct", "all CPUs %"), ("gpu_busy_pct", "GPU busy %"),
    ("quickshell_rcs_pct", "QS render %"), ("hyprland_rcs_pct", "Hyprland render %"),
    ("gpu_card_w", "GPU card W"), ("cpu_pkg_w", "CPU pkg W"),
    ("fps_DP-1", "DP-1 fps"), ("fps_DP-2", "DP-2 fps"),
]


def run_text(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=15).stdout.strip()
    except OSError:
        return None


def environment(profile):
    gt = "/sys/class/drm/card0/device/tile0/gt0/freq0/"
    return {
        "hyprland": run_text("hyprctl", "version", "-j"),
        "kernel": platform.release(),
        "monitors": run_text("hyprctl", "-j", "monitors"),
        "plugins": run_text("hyprctl", "plugin", "list"),
        "power_profile": profile,
        "gpu_min_max_mhz": [run_text("cat", gt + "min_freq"), run_text("cat", gt + "max_freq")],
        "top": run_text("ps", "-eo", "pcpu,rss,comm", "--sort=-pcpu", "--no-headers")[:1500],
        "load": open("/proc/loadavg").read().strip(),
    }


def fmt(v):
    return "-" if v is None else f"{v:.1f}"


def brief(row):
    flag = f"  INVALID: {row['invalid']}" if row.get("invalid") else ""
    return "  ".join(f"{label}={fmt(row.get(key))}" for key, label in COLUMNS[:4]) + flag


def aggregate(rows):
    """{(scenario, workload): {metric: (mean, sd, n)}} over the valid rows."""
    groups = {}
    for row in rows:
        if not row.get("invalid"):
            groups.setdefault((row["scenario"], row["workload"]), []).append(row)
    out = {}
    for key, group in groups.items():
        metrics = sorted({m for r in group for m, v in r.items() if isinstance(v, float)})
        out[key] = {}
        for m in metrics:
            vals = [r[m] for r in group if isinstance(r.get(m), float)]
            sd = statistics.stdev(vals) if len(vals) > 1 else None
            out[key][m] = (statistics.fmean(vals), sd, len(vals))
    return out


def delta(agg, scenario, workload, metric):
    """Percent change against the baseline A for the same workload, or None."""
    base = agg.get(("A", workload), {}).get(metric)
    cur = agg.get((scenario, workload), {}).get(metric)
    if not base or not cur or base[0] == 0:
        return None
    return 100 * (cur[0] - base[0]) / base[0]


def markdown(env, rows, agg, args):
    lines = ["# hypr-bench run", "",
             f"Rounds {args.get('rounds')}, scenarios {''.join(args.get('scenarios', []))},"
             f" idle {args.get('idle')} s, others {args.get('short')} s,"
             f" settle {args.get('settle')} s, privileged {args.get('privileged')}.",
             f"Kernel {env.get('kernel')}, power profile {env.get('power_profile')},"
             f" load {env.get('load')}.", ""]
    invalid = [r for r in rows if r.get("invalid")]
    if invalid:
        lines += [f"{len(invalid)} block(s) left out: "
                  + "; ".join(f"{r['scenario']}/{r['workload']} ({r['invalid']})" for r in invalid), ""]
    present = [(k, label) for k, label in COLUMNS if any(k in v for v in agg.values())]
    for workload in dict.fromkeys(r["workload"] for r in rows):
        lines += [f"## {workload}", "",
                  "| scenario | " + " | ".join(label for _, label in present) + " |",
                  "| --- |" + " ---: |" * len(present)]
        for sc in dict.fromkeys(r["scenario"] for r in rows):
            cells = []
            for key, _ in present:
                v = agg.get((sc, workload), {}).get(key)
                d = delta(agg, sc, workload, key) if sc != "A" else None
                cell = "-" if v is None else fmt(v[0]) + (f" ±{fmt(v[1])}" if v[1] else "")
                cells.append(cell + (f" ({d:+.0f}%)" if d is not None else ""))
            lines.append(f"| {sc} | " + " | ".join(cells) + " |")
        lines.append("")
    return "\n".join(lines)


def write(run_dir, env, rows, args):
    args = vars(args) if not isinstance(args, dict) else args
    agg = aggregate(rows)
    json.dump({"env": env, "args": args, "rows": rows}, open(os.path.join(run_dir, "raw.json"), "w"),
              indent=1)
    keys = sorted({k for r in rows for k in r})
    with open(os.path.join(run_dir, "rows.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        w.writerows(rows)
    summary = {f"{s}/{w}": {m: {"mean": v[0], "sd": v[1], "n": v[2]} for m, v in ms.items()}
               for (s, w), ms in agg.items()}
    json.dump(summary, open(os.path.join(run_dir, "summary.json"), "w"), indent=1)
    open(os.path.join(run_dir, "report.md"), "w").write(markdown(env, rows, agg, args))


def rewrite(run_dir):
    raw = json.load(open(os.path.join(run_dir, "raw.json")))
    write(run_dir, raw["env"], raw["rows"], raw["args"])
    print(open(os.path.join(run_dir, "report.md")).read())
