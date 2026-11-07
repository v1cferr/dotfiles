"""Counters the desktop exposes, read without changing anything.

A snapshot is a flat dict of MONOTONIC counters plus a few gauges; rates() turns two snapshots
into per-second numbers. Every reader returns None when its source is missing or unreadable, so a
metric that cannot be measured stays absent instead of becoming a zero.
"""
import glob
import json
import os
import re
import subprocess
import time

TICK = os.sysconf("SC_CLK_TCK")
GT = sorted(glob.glob("/sys/class/drm/card*/device/tile0/gt0"))
HWMON = [h for h in glob.glob("/sys/class/hwmon/hwmon*") if open(h + "/name").read().strip() == "xe"]
RAPL = "/sys/class/powercap/intel-rapl:0/energy_uj"
WATCHED = {"hyprland": ".Hyprland-wrapp", "quickshell": ".quickshell-wra", "xwayland": "Xwayland"}


def read(path):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return None


def number(path):
    text = read(path)
    return float(text.split()[0]) if text else None


def sudo_reader():
    """--privileged: root reads (Hyprland's fdinfo and smaps, RAPL), and nothing else.

    Hyprland holds CAP_SYS_NICE, which makes it non-dumpable: its /proc files are root-only.
    """
    print("hypr-bench: sudo is used ONLY to read Hyprland's /proc fdinfo/smaps and RAPL energy")
    subprocess.run(["sudo", "-v"], check=True)

    def private(path, glob_root=False):
        script = f'for f in {path}; do cat "$f"; echo; done' if glob_root else f"cat {path}"
        subprocess.run(["sudo", "-n", "-v"], capture_output=True)  # keep the timestamp fresh
        out = subprocess.run(["sudo", "-n", "sh", "-c", script], capture_output=True, text=True,
                             timeout=10)
        return out.stdout if out.returncode == 0 else None
    return private


def find_pids():
    """The live compositor, the live shell (never the lock screen's qs) and Xwayland."""
    pids = {}
    for comm_path in glob.glob("/proc/[0-9]*/comm"):
        comm = (read(comm_path) or "").strip()
        for name, want in WATCHED.items():
            if comm == want and name not in pids:
                pid = comm_path.split("/")[2]
                if name == "quickshell" and "lock" in (read(f"/proc/{pid}/cmdline") or ""):
                    continue
                pids[name] = int(pid)
    return pids


def proc_cpu_ticks(pid):
    text = read(f"/proc/{pid}/stat")
    if not text:
        return None
    fields = text.rsplit(")", 1)[1].split()
    return int(fields[11]) + int(fields[12])  # utime + stime, after the comm field


def proc_mem_kib(pid, private):
    status = read(f"/proc/{pid}/status") or ""
    rss = re.search(r"^VmRSS:\s+(\d+)", status, re.M)
    rollup = read(f"/proc/{pid}/smaps_rollup") or (private(f"/proc/{pid}/smaps_rollup") or "")
    pss = re.search(r"^Pss:\s+(\d+)", rollup, re.M)
    return (int(rss.group(1)) if rss else None, int(pss.group(1)) if pss else None)


def parse_fdinfo(text):
    """Sum the xe render-engine cycles over every DRM client of one process (one per client id)."""
    clients = {}
    for block in text.split("\n\n"):
        cid = re.search(r"drm-client-id:\s+(\d+)", block)
        busy = re.search(r"drm-cycles-rcs:\s+(\d+)", block)
        total = re.search(r"drm-total-cycles-rcs:\s+(\d+)", block)
        if cid and busy and total:
            clients[cid.group(1)] = (int(busy.group(1)), int(total.group(1)))
    if not clients:
        return None
    return sum(b for b, _ in clients.values()), max(t for _, t in clients.values())


def gpu_cycles(pid, private):
    blocks = []
    for path in glob.glob(f"/proc/{pid}/fdinfo/*"):
        text = read(path)
        if text and "drm-driver:\txe" in text:
            blocks.append(text)
    if not blocks and private:
        blocks = [private(f"/proc/{pid}/fdinfo/*", glob_root=True) or ""]
    return parse_fdinfo("\n\n".join(blocks))


def hyprglass_frames():
    """Frames composed per output, from HyprGlass's own counters (they keep counting when off)."""
    try:
        out = subprocess.run(["hyprctl", "-j", "hyprglass", "stats"], capture_output=True,
                             text=True, timeout=5).stdout
        return {m["name"]: m["frames"] for m in json.loads(out)["monitors"]}
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired):
        return {}


def cpu_cores():
    cores = {}
    for line in (read("/proc/stat") or "").splitlines():
        if re.match(r"cpu\d+ ", line):
            name, *vals = line.split()
            vals = [int(v) for v in vals[:8]]
            cores[name] = (sum(vals) - vals[3] - vals[4], sum(vals))  # busy, total (idle+iowait out)
    return cores


def snapshot(private=None):
    snap = {"t": time.monotonic(), "frames": hyprglass_frames(), "cores": cpu_cores(), "procs": {}}
    for name, pid in find_pids().items():
        rss, pss = proc_mem_kib(pid, private or (lambda *_a, **_k: None))
        snap["procs"][name] = {"ticks": proc_cpu_ticks(pid), "rss": rss, "pss": pss,
                               "gpu": gpu_cycles(pid, private)}
    if GT:
        snap["rc6_ms"] = number(GT[0] + "/gtidle/idle_residency_ms")
        snap["freq_mhz"] = number(GT[0] + "/freq0/act_freq")
    for h in HWMON:
        for e in glob.glob(h + "/energy*_input"):
            label = (read(e.replace("_input", "_label")) or "e").strip()
            snap["gpu_" + label + "_uj"] = number(e)
    cpu_pkg = read(RAPL) or (private(RAPL) if private else None)
    snap["cpu_pkg_uj"] = float(cpu_pkg) if cpu_pkg and cpu_pkg.strip().isdigit() else None
    return snap


def ratio(a, b, key, scale):
    if a.get(key) is None or b.get(key) is None:
        return None
    return (b[key] - a[key]) * scale


def rates(a, b):
    """Two snapshots into one row of per-second rates and end-of-window gauges."""
    dt = b["t"] - a["t"]
    row = {"seconds": round(dt, 2)}
    for name, pb in b["procs"].items():
        pa = a["procs"].get(name)
        if pa and pa["ticks"] is not None and pb["ticks"] is not None:
            row[f"{name}_cpu_pct"] = 100 * (pb["ticks"] - pa["ticks"]) / TICK / dt
        row[f"{name}_rss_mib"] = pb["rss"] / 1024 if pb["rss"] else None
        row[f"{name}_pss_mib"] = pb["pss"] / 1024 if pb["pss"] else None
        if pa and pa["gpu"] and pb["gpu"] and pb["gpu"][1] > pa["gpu"][1]:
            row[f"{name}_rcs_pct"] = 100 * (pb["gpu"][0] - pa["gpu"][0]) / (pb["gpu"][1] - pa["gpu"][1])
    busy = [(b["cores"][c][0] - a["cores"][c][0]) / max(1, b["cores"][c][1] - a["cores"][c][1])
            for c in b["cores"] if c in a["cores"]]
    if busy:
        row["cpu_all_pct"] = 100 * sum(busy) / len(busy)
        row["cpu_max_core_pct"] = 100 * max(busy)
    rc6 = ratio(a, b, "rc6_ms", 1 / (1000 * dt))
    row["gpu_busy_pct"] = None if rc6 is None else 100 * (1 - min(1.0, rc6))
    for key in [k for k in b if k.endswith("_uj")]:
        joules = ratio(a, b, key, 1e-6)
        row[key.replace("_uj", "_w")] = None if joules is None else joules / dt
    for out, frames in b["frames"].items():
        if out in a["frames"]:
            row[f"fps_{out}"] = (frames - a["frames"][out]) / dt
    return row
