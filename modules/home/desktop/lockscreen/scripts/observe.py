"""The observability adapter: read-only snapshots of power-log, glance-feed's claude_usage and /proc,
each with its source, timestamp, status and history. One source per metric. docs/notes/desktop/lockscreen.md

  observe.py json energy|claude|system|procs     one snapshot, JSON on stdout (Quickshell reads it)
  observe.py lock-loop --out DIR [--once]        the lock's LG cards as pango markup, refreshed in place
"""

import argparse
import csv
import json
import os
import re
import sqlite3
import statistics
import sys
import time
from pathlib import Path

POWER_DIR = Path(os.environ.get("OBSERVE_POWER_DIR", "/var/lib/power-log"))
GLANCE_DB = Path(os.environ.get("OBSERVE_GLANCE_DB", os.path.expanduser("~/.cache/glance/glance.db")))
PROC = Path(os.environ.get("OBSERVE_PROC", "/proc"))
SYS = Path(os.environ.get("OBSERVE_SYS", "/sys"))
HZ = os.sysconf("SC_CLK_TCK") if hasattr(os, "sysconf") else 100
PAGE = os.sysconf("SC_PAGE_SIZE") if hasattr(os, "sysconf") else 4096

POWER_STALE = 180  # power-log writes every minute: three missed samples is stale
CLAUDE_STALE = 600  # glance-feed asks every minute: ten minutes without an answer is stale


# ── Energy: power-log's CSV, never a second logger ─────────────────────────────────────────


def _rows(now: float, seconds: int) -> list:
    """The power-log rows of the last `seconds`, oldest first, across a month boundary."""
    files = sorted(POWER_DIR.glob("*.csv"))[-2:]
    out = []
    for f in files:
        try:
            with open(f, newline="") as fh:
                for r in csv.DictReader(fh):
                    try:
                        t = time.mktime(time.strptime(r["time"][:19], "%Y-%m-%dT%H:%M:%S"))
                    except (KeyError, ValueError):
                        continue
                    if now - seconds <= t <= now + 60:
                        r["_t"] = t
                        out.append(r)
        except OSError:
            continue
    return sorted(out, key=lambda r: r["_t"])


def _num(r: dict, k: str):
    try:
        v = r.get(k)
        return float(v) if v not in (None, "") else None
    except ValueError:
        return None


def energy(now: float | None = None, window: int = 1800) -> dict:
    """The last 30 min of MEASURED CPU package + GPU board watts, and an Eco-idle baseline from the
    same logger over 7 days (power-saver profile, CPU under 10% busy): comparable conditions only."""
    now = now or time.time()
    rows = _rows(now, 7 * 86400)
    recent = [r for r in rows if r["_t"] >= now - window]
    out = {"source": "power-log", "unit": "W", "label": "CPU + GPU measured", "status": "missing",
           "timestamp": None, "age": None, "history": [], "baseline": None}
    if rows:
        last = rows[-1]
        age = now - last["_t"]
        out.update({
            "status": "ok" if age <= POWER_STALE else "stale",
            "timestamp": int(last["_t"]),
            "age": int(age),
            "measured_w": _num(last, "measured_w"),
            "cpu_w": _num(last, "cpu_package_w"),
            "gpu_w": _num(last, "gpu_board_w"),
            "profile": last.get("profile") or None,
            "render_idle_pct": _num(last, "gpu_render_idle_pct"),
            "cpu_busy_pct": _num(last, "cpu_busy_pct"),
            "temps": {k: _num(last, k) for k in ("cpu_c", "gpu_c", "nvme_c")},
        })
    # One point per minute slot: a slot with no sample is a hole (None), never a zero.
    slots = window // 60
    by_slot = {}
    for r in recent:
        i = int((r["_t"] - (now - window)) // 60)
        if 0 <= i < slots:
            by_slot[i] = _num(r, "measured_w")
    out["history"] = [by_slot.get(i) for i in range(slots)]
    # Comparable means idle on BOTH sides: Eco alone also catches a Moonlight stream (measured: a
    # 72 W median), the GPU's render idle keeps only the desk at rest (53 W, p10-p90 52-55 W).
    idle = [w for r in rows
            if r.get("profile") == "power-saver" and (_num(r, "cpu_busy_pct") or 100) < 10
            and (_num(r, "gpu_render_idle_pct") or 0) > 70 and (w := _num(r, "measured_w")) is not None]
    if len(idle) >= 30:
        out["baseline"] = {"median_w": round(statistics.median(idle), 1), "samples": len(idle),
                           "condition": "power-saver, CPU < 10% busy, GPU render idle > 70%, last 7 days"}
    return out


# ── Claude: glance-feed's document, read-only, never the network ───────────────────────────


def _live(w, now):
    """A window whose reset already passed is EMPTY until the feed says otherwise (ClaudeUsage.qml)."""
    if not isinstance(w, dict) or w.get("pct") is None:
        return {"pct": None, "resets": None}
    if w.get("resets") and w["resets"] <= now:
        return {"pct": 0, "resets": None}
    return {"pct": w.get("pct"), "resets": w.get("resets")}


WEEK_BUCKETS = 42  # 7 days of 4 h: wide enough to read, fine enough to see a day's work


def week_history(samples: list, now: float, resets_at) -> dict:
    """The weekly share over the last 7 days, one value per 4 h bucket, each the last value KNOWN at
    its end (a step chart); before the first sample, None (a hole, never a zero). A drop is a reset:
    "observed" when it spans the documented weekly boundary (the next reset minus 7 days), else
    "inferred" (the feed saw the number fall, not the reset itself)."""
    hist = sorted((h for h in samples if isinstance(h, dict) and isinstance(h.get("ts"), (int, float))),
                  key=lambda h: h["ts"])
    step = 7 * 86400 / WEEK_BUCKETS
    series, j, v = [], 0, None
    for k in range(WEEK_BUCKETS):
        end = now - (WEEK_BUCKETS - 1 - k) * step
        while j < len(hist) and hist[j]["ts"] <= end:
            x = hist[j].get("w")
            v = None if x is None else max(0.0, min(100.0, float(x)))
            j += 1
        series.append(v)
    boundary = resets_at - 7 * 86400 if resets_at else None
    resets = []
    for a, b in zip(hist, hist[1:]):
        if a.get("w") is not None and b.get("w") is not None and b["w"] < a["w"] and b["ts"] > now - 7 * 86400:
            resets.append({"ts": b["ts"], "observed": boundary is not None and a["ts"] <= boundary <= b["ts"]})
    return {"w": series, "resets": resets, "start": hist[0]["ts"] if hist else None}


def claude(now: float | None = None) -> dict:
    now = now or time.time()
    out = {"source": "glance-feed:claude_usage", "unit": "%", "status": "missing", "account": "FAI",
           "timestamp": None, "age": None, "error": None, "session": {"pct": None, "resets": None},
           "weekly": {"pct": None, "resets": None}, "history": {"w": [], "resets": [], "start": None}}
    try:
        db = sqlite3.connect(f"file:{GLANCE_DB}?mode=ro", uri=True, timeout=2)
        row = db.execute("select json, updated_at, checked_at, error from feed where name = ?",
                         ("claude_usage",)).fetchone()
        db.close()
    except sqlite3.Error as e:
        out["error"] = f"cache unreadable: {e.__class__.__name__}"
        return out
    if not row:
        return out
    try:
        doc = json.loads(row[0])
    except ValueError:
        out["error"] = "malformed document"
        return out
    checked = row[2] or 0
    out["timestamp"] = int(checked)
    out["age"] = int(now - checked)
    if not doc.get("ok"):
        out["status"] = "error"
        out["error"] = doc.get("error") or row[3] or "unknown"
        return out
    out["status"] = "ok" if now - checked <= CLAUDE_STALE else "stale"
    out["error"] = row[3]
    out["plan"] = doc.get("plan")
    out["session"] = _live(doc.get("session"), now)
    out["weekly"] = _live(doc.get("weekly"), now)
    out["history"] = week_history(doc.get("history") or [], now, out["weekly"].get("resets"))
    return out


# ── System and processes: /proc deltas between two samples ─────────────────────────────────


def _read(p: Path) -> str:
    try:
        return p.read_text()
    except OSError:
        return ""


def _cpu_ticks():
    f = _read(PROC / "stat").split("\n", 1)[0].split()
    if not f or f[0] != "cpu":
        return None
    v = list(map(int, f[1:]))
    idle = v[3] + (v[4] if len(v) > 4 else 0)
    return sum(v[:8]), idle


def _meminfo() -> dict:
    m = {}
    for line in _read(PROC / "meminfo").splitlines():
        k, _, rest = line.partition(":")
        try:
            m[k] = int(rest.split()[0]) * 1024
        except (IndexError, ValueError):
            pass
    return m


def _gpu_paths():
    hw = next((d for d in sorted((SYS / "class/hwmon").glob("hwmon*")) if _read(d / "name").strip() == "xe"), None)
    gt = next(iter(sorted((SYS / "class/drm").glob("card*/device/tile0/gt0"))), None)
    return hw, gt


def _gpu_raw():
    hw, gt = _gpu_paths()
    energy_uj = rc6 = freq = None
    try:
        energy_uj = int(_read(hw / "energy1_input")) if hw else None
    except ValueError:
        pass
    try:
        rc6 = int(_read(gt / "gtidle/idle_residency_ms")) if gt else None
        freq = int(_read(gt / "freq0/act_freq")) if gt else None
    except ValueError:
        pass
    return energy_uj, rc6, freq


def sample() -> dict:
    """One raw sample: what a delta needs. Cheap: a few small reads plus one pass over /proc."""
    t = time.monotonic()
    return {"t": t, "cpu": _cpu_ticks(), "gpu": _gpu_raw(), "procs": _procs_raw()}


def system(prev: dict, cur: dict, now: float | None = None) -> dict:
    """CPU from /proc/stat deltas, memory from MemAvailable (cache is NOT counted as used), GPU as
    board power, frequency and render idle: the xe driver has no utilization percentage, so none."""
    now = now or time.time()
    dt = cur["t"] - prev["t"]
    out = {"source": "/proc, /sys", "timestamp": int(now), "status": "ok", "interval_s": round(dt, 1)}
    if prev["cpu"] and cur["cpu"] and cur["cpu"][0] > prev["cpu"][0]:
        tot = cur["cpu"][0] - prev["cpu"][0]
        idle = cur["cpu"][1] - prev["cpu"][1]
        out["cpu_pct"] = round(100 * (tot - idle) / tot, 1)
    else:
        out["cpu_pct"] = None
    m = _meminfo()
    if "MemTotal" in m and "MemAvailable" in m:
        out["mem"] = {"total": m["MemTotal"], "available": m["MemAvailable"],
                      "used": m["MemTotal"] - m["MemAvailable"]}
        if m.get("SwapTotal"):
            out["swap"] = {"total": m["SwapTotal"], "used": m["SwapTotal"] - m.get("SwapFree", 0)}
    (e0, r0, _), (e1, r1, f1) = prev["gpu"], cur["gpu"]
    gpu = {"freq_mhz": f1}
    if e0 is not None and e1 is not None and dt > 0 and e1 >= e0:
        gpu["board_w"] = round((e1 - e0) / 1e6 / dt, 1)
    if r0 is not None and r1 is not None and dt > 0:
        gpu["render_idle_pct"] = round(min(100.0, max(0.0, 100 * (r1 - r0) / 1000 / dt)), 1)
    out["gpu"] = gpu
    return out


_UNIT = re.compile(r"(?:^|/)([^/]+\.(?:service|scope))$")
_APP = re.compile(r"^app-(?:Hyprland-|flatpak-|gnome-|kde-)?(.+?)(?:-[0-9a-f]{6,}|-\d+|@[^.]*)?\.(?:scope|service)$")
# Nix wraps binaries as `.name-wrapped`, and comm keeps 15 bytes of it: `.quickshell-wra`.
_WRAPPED = re.compile(r"^\.(.+?)-w(?:r(?:a(?:p(?:p(?:e(?:d)?)?)?)?)?)?$")


def group_of(cgroup: str, comm: str) -> str:
    """An APPLICATION name from the systemd unit (children grouped with their app), else the
    process name. Never a command line: no arguments, paths or documents ever leave /proc."""
    w = _WRAPPED.match(comm)
    comm = w.group(1) if w else comm
    m = _UNIT.search(cgroup.strip())
    if m:
        unit = m.group(1)
        if unit.startswith("session-") or unit.startswith("user@"):
            return comm
        a = _APP.match(unit)
        name = a.group(1) if a else unit.rsplit(".", 1)[0]
        return name.replace("\\x2d", "-").replace("\\x20", " ")
    return comm


def _procs_raw() -> dict:
    out = {}
    for d in PROC.iterdir():
        if not d.name.isdigit():
            continue
        st = _read(d / "stat")
        if not st:
            continue
        try:
            rest = st[st.rindex(")") + 2:].split()
            ppid, utime, stime, start = int(rest[1]), int(rest[11]), int(rest[12]), int(rest[19])
            rss = int(_read(d / "statm").split()[1]) * PAGE
        except (ValueError, IndexError):
            continue
        if ppid == 2 or d.name == "2":
            continue  # kernel threads: no app to name, no memory to rank
        comm = _read(d / "comm").strip() or "?"
        cg = _read(d / "cgroup").splitlines()
        out[(int(d.name), start)] = (group_of(cg[0].partition("::")[2] if cg else "", comm),
                                     utime + stime, rss)
    return out


def procs(prev: dict, cur: dict, top: int = 4) -> dict:
    """The heaviest APPLICATIONS now: CPU from the tick delta of the same (pid, start time), so a
    reused PID never inherits another's ticks, as % of ONE core; memory as summed RSS (shared pages
    are counted once per process, so an app with many processes reads high)."""
    dt = cur["t"] - prev["t"]
    cpu, mem = {}, {}
    for key, (grp, ticks, rss) in cur["procs"].items():
        mem[grp] = mem.get(grp, 0) + rss
        old = prev["procs"].get(key)
        if old and dt > 0:
            cpu[grp] = cpu.get(grp, 0.0) + max(0, ticks - old[1]) / HZ / dt * 100
    rank = lambda d: sorted(d.items(), key=lambda kv: -kv[1])[:top]  # noqa: E731
    return {"source": "/proc", "status": "ok" if cur["procs"] else "missing", "interval_s": round(dt, 1),
            "cpu_unit": "% of one core", "mem_unit": "RSS bytes, summed per app",
            "cpu": [{"name": k, "value": round(v, 1)} for k, v in rank(cpu) if v >= 0.1],
            "mem": [{"name": k, "value": v} for k, v in rank(mem)]}


# ── The lock's cards: pango markup, cut to their columns ───────────────────────────────────


def esc(s: str) -> str:
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def ago(seconds) -> str:
    if seconds is None:
        return "–"
    s = int(seconds)
    if s < 90:
        return "agora"
    if s < 5400:
        return f"há {round(s / 60)} min"
    return f"há {round(s / 3600)} h"


def until(t, now) -> str:
    if not t:
        return ""
    s = max(0, int(t - now))
    if s >= 86400:
        return f"{s // 86400}d {s % 86400 // 3600}h"
    if s >= 3600:
        return f"{s // 3600}h {s % 3600 // 60:02d}m"
    return f"{max(1, -(-s // 60))} min"


def fmt_bytes(n) -> str:
    if n is None:
        return "–"
    g = n / 1024**3
    return f"{g:.1f} GB" if g >= 1 else f"{n / 1024**2:.0f} MB"


def fit(s: str, cols: int) -> str:
    s = re.sub(r"[\x00-\x1f]", "", str(s))
    return s if len(s) <= cols else s[: cols - 1] + "…"


PROFILE = {"power-saver": "Eco", "balanced": "Balanced", "performance": "Gaming"}


BODY_PT = 15  # the cards' running text: --cols/--half count columns at this size, 0.84 px per pt each
META_PT = 13
CAPS_PT = 12
# The lock's type (default.nix passes the same with --type): families for numbers, icons and charts,
# and how wide one Sparks data point is in em (measured with pango 1.57: line 0.35, bars 0.30).
TYPE = {"display": "Geist", "data": "Geist Mono", "icons": "Material Symbols Rounded", "iconWeight": 300,
        "chart": "Sparks Dot-line Thick,", "chartEm": 0.35, "bars": "Sparks Bar Medium,", "barsEm": 0.30}
# Material Symbols' progress glyphs, by the share they stand for (the font has these six steps).
RINGS = [(15, "clock_loader_10"), (30, "clock_loader_20"), (50, "clock_loader_40"), (70, "clock_loader_60"),
         (85, "clock_loader_80"), (100, "clock_loader_90")]


def ring_glyph(pct) -> tuple:
    """(icon, filled) for a share: nothing read or nothing used is the empty circle, a full one the
    filled circle, and anything between the nearest progress step at or above it."""
    if pct is None or pct <= 0:
        return ("circle", False)
    if pct >= 100:
        return ("circle", True)
    return (next(name for top, name in RINGS if pct <= top), False)


def icon(name: str, pt: int, color: str, filled: bool = False) -> str:
    """A Material Symbols ligature at the type's weight: the icon is as thin as the text beside it."""
    axes = f'@wght={TYPE["iconWeight"]}' + (",FILL=1" if filled else "")
    return f'<span font_desc="{TYPE["icons"]} {pt} {axes}" foreground="#{color}">{name}</span>'


def hero(text: str, pt: int, color: str = "", weight: int = 200, face: str = "display") -> str:
    """A card's number, tabular: large and LIGHT, so size carries it (`face="data"` for a column)."""
    fg = f' foreground="#{color}"' if color else ""
    return (f'<span font_family="{TYPE[face]}" font_features="tnum" size="{pt * 1024}"'
            f' font_weight="{weight}"{fg}>{text}</span>')


def caps(text: str, color: str) -> str:
    """A small tracked label in caps: what the number beside it is."""
    return (f'<span size="{CAPS_PT * 1024}" letter_spacing="2048" foreground="#{color}">'
            f'<b>{esc(text.upper())}</b></span>')


def meta(text: str, color: str) -> str:
    return f'<span size="{META_PT * 1024}" foreground="#{color}">{text}</span>'


def gap(px: int) -> str:
    """A spacer line `px` tall: blocks in one label breathe without a second label."""
    return f'<span size="{max(1, round(px * 0.75)) * 1024}"> </span>'


def meter(frac, cols: int, color: str, track: str) -> str:
    """A thin bar, filled in the card's color over a dim track: a share you read without a number."""
    if frac is None:
        return f'<span foreground="#{track}">' + "━" * cols + "</span>"
    n = max(0, min(cols, round(frac * cols)))
    return f'<span foreground="#{color}">' + "━" * n + f'</span><span foreground="#{track}">' + "━" * (cols - n) + "</span>"


def sparkline(series: list, top: float, width_px: float, color: str, bottom: float = 0, kind: str = "chart") -> str:
    """A chart drawn by the Sparks font: its `calt` turns `{10,40,90}` into a line (`chart`) or bars
    (`bars`). Values from `bottom` to `top` on its 0 to 100, sized so the points span `width_px`;
    a hole ends the run and leaves a gap of the same width, drawn invisible: never a zero, and never
    a space (whose width is not a data point's, which would shift everything after it)."""
    pt = max(8, int(width_px / max(1, len(series)) / (TYPE[kind + "Em"] * 96 / 72)))
    span = top - bottom
    out, run, holes = "", [], 0
    for v in series + [0.0]:
        if v is None:
            if run:
                out += "{" + ",".join(run) + "}"
                run = []
            holes += 1
            continue
        if holes:
            out += '<span alpha="1%">{' + ",".join(["0"] * holes) + "}</span>"
            holes = 0
        run.append(str(0 if span <= 0 else max(0, min(100, round((v - bottom) / span * 100)))))
    run.pop()  # the sentinel that closed the last hole
    if run:
        out += "{" + ",".join(run) + "}"
    return f'<span font_desc="{TYPE[kind]} {pt}" foreground="#{color}">{out}</span>'


def px(cols: int, pt: int = BODY_PT) -> float:
    return cols * pt * 0.84


def spread(left: str, right: str, cols: int) -> str:
    """Two plain strings on one monospace line, flush left and flush right."""
    return left + " " * max(1, cols - len(left) - len(right)) + right


def card_energy(e: dict, pal: dict, cols: int = 69) -> str:
    """Energy: the measured watts, the last 30 min as a line, the CPU package and GPU board split,
    and one line of what the numbers are. Never the PC's power: there is no wall meter."""
    sub, dim, tone = pal["subtext"], pal["dim"], pal["orange"]
    if e["status"] == "missing" or e.get("measured_w") is None:
        return meta("Sem medições do power-log", sub)
    seen = [v for v in e["history"] if v is not None] or [1]
    peak = max(seen)
    # A LINE chart, so the scale hugs the data (a round range around it) and is printed under it.
    top, bottom = -(-peak // 25) * 25, min(seen) // 25 * 25
    tot = e["measured_w"] or 1
    half = cols // 2

    def share(name, w):
        head = f"{name}  {w:5.1f} W  "
        return f'<span foreground="#{sub}">{head}</span>' + meter(w / tot, half - len(head) - 2, tone, dim)

    notes = ["Últimos 30 min", f"{bottom:.0f} a {top:.0f} W", f"pico {peak:.0f} W"]
    if e["baseline"]:
        notes.append(f'Eco em repouso {e["baseline"]["median_w"]:.0f} W')
    notes.append(PROFILE.get(e["profile"] or "", e["profile"] or "–"))
    when = ago(e["age"])
    if e["status"] == "stale":
        notes.insert(0, f"DESATUALIZADO, {when}")
    return "\n".join([
        hero(f'{e["measured_w"]:.0f}', 56) + hero(" W", 22, sub, 300) + "   " + meta("CPU + GPU medidos", sub),
        sparkline(e["history"], top, px(cols), tone, bottom),
        share("CPU package", e["cpu_w"]) + "  " + share("GPU board", e["gpu_w"]),
        meta(" · ".join(notes), sub),
    ])


def cards_claude(c: dict, pal: dict, now: float, cols: int = 69) -> dict:
    """Claude Code: the 5 h session and the week as current numbers side by side, then the WEEK's
    last 7 days as held bars on a true 0 to 100% scale (one chart, not two near-identical ones)."""
    sub = pal["subtext"]
    if c["status"] in ("missing", "error"):
        why = {"no-credentials": "sem login da conta FAI"}.get(c.get("error"), c.get("error") or "sem dados")
        return {"claude-s": meta(esc(why), sub), "claude-w": "", "claude-h": ""}

    def now_block(cap, w, tone):
        pct = w["pct"]
        ring, full = ring_glyph(pct)
        reset = f'reinicia em {until(w["resets"], now)}' if w["resets"] else "sem janela aberta"
        if c["status"] == "stale":
            reset = f'DESATUALIZADO, {ago(c["age"])}'
        return "\n".join([
            icon(ring, 32, tone, full) + "  " + hero("–" if pct is None else f"{round(pct)}%", 40),
            caps(cap, sub),
            meta(reset, sub),
        ])

    h = c["history"]
    mcols = int(px(cols) / (META_PT * 0.84))
    axis = spread("há 7 dias", "agora", mcols)
    if h.get("start") and h["start"] > now - 7 * 86400 + 4 * 3600:
        axis = spread(f'coletando desde {time.strftime("%d/%m %H:%M", time.localtime(h["start"]))}', "agora", mcols)
    lines = [sparkline(h["w"], 100, px(cols), pal["magenta"], kind="bars"), meta(axis, sub)]
    if h.get("resets"):
        r = h["resets"][-1]
        how = "observado" if r["observed"] else "queda inferida"
        lines.append(meta(f'Reinício semanal {time.strftime("%d/%m %H:%M", time.localtime(r["ts"]))} ({how})', sub))
    return {
        "claude-s": now_block("Sessão · 5 h", c["session"], pal["orange"]),
        "claude-w": now_block("Limite semanal", c["weekly"], pal["magenta"]),
        "claude-h": "\n".join(lines),
    }


def card_system(s: dict, e: dict, pal: dict, cols: int = 31) -> str:
    """System: CPU, RAM and the GPU's render activity, each a short caps name with its details in
    meta, then the number and a meter. The GPU's watts are the energy card's, so they are not
    repeated; `xe` has no utilization percentage, so the GPU number is render ACTIVE time, said so."""
    sub, dim, tone = pal["subtext"], pal["dim"], pal["blue"]
    m = s.get("mem") or {}
    g = s.get("gpu") or {}
    t = (e or {}).get("temps") or {}
    temp = lambda k: [] if t.get(k) is None else [f"{t[k]:.0f} °C"]  # noqa: E731
    bar = 14

    def block(name, notes, value, frac):
        return (caps(name, sub) + "   " + meta(" · ".join(notes), sub) + "\n"
                + hero(esc(value.ljust(8)), 24, face="data") + meter(frac, bar, tone, dim))  # one column for every meter

    cpu = s.get("cpu_pct")
    busy = None if g.get("render_idle_pct") is None else 100 - g["render_idle_pct"]
    freq = g.get("freq_mhz")
    clock = [] if freq is None else ["em repouso" if freq == 0 else f"{freq / 1000:.2f} GHz".replace(".", ",")]
    return f"\n{gap(6)}\n".join([
        block("CPU", ["uso"] + temp("cpu_c"), "–" if cpu is None else f"{cpu:.0f}%", None if cpu is None else cpu / 100),
        block("RAM", ["em uso", f'livre {fmt_bytes(m.get("available"))}'], fmt_bytes(m.get("used")),
              m["used"] / m["total"] if m.get("total") else None),
        block("GPU", ["render ativo"] + clock + temp("gpu_c"), "–" if busy is None else f"{busy:.0f}%",
              None if busy is None else busy / 100),
    ])


def card_apps(p: dict, pal: dict, cols: int = 31) -> str:
    """Processes: the three apps using the most CPU now and the three holding the most memory,
    grouped by app; only the unit or process name, never a command line or a path."""
    sub, dim, tone = pal["subtext"], pal["dim"], pal["teal"]
    name_w, val_w = 12, 7
    bar = cols - name_w - val_w - 2

    def rows(items, fmt):
        if not items:
            return [meta("–", sub)]
        topv = max(i["value"] for i in items) or 1
        # Padded BEFORE escaping, so an `&` in a name never shifts the column.
        return [esc(fit(i["name"], name_w).ljust(name_w)) + " " + meter(i["value"] / topv, bar, tone, dim)
                + f'<span foreground="#{sub}">{fmt(i["value"]):>{val_w}}</span>' for i in items[:3]]

    return "\n".join([caps("CPU agora · % de um núcleo", sub)] + rows(p["cpu"], lambda v: f"{v:.0f}%")
                     + [gap(12), caps("Memória · RSS por app", sub)] + rows(p["mem"], fmt_bytes))


def write_card(out: Path, name: str, markup: str) -> None:
    """`pid\\nepoch\\nmarkup`, atomically: the label shows it only while this writer is alive."""
    tmp = out / f".{name}.{os.getpid()}"
    tmp.write_text(f"{os.getpid()}\n{int(time.time())}\n{markup}")
    os.replace(tmp, out / name)


def lock_loop(out: Path, pal: dict, cols: dict, once: bool, fast: int, slow: int) -> int:
    out.mkdir(parents=True, exist_ok=True)
    prev = sample()
    time.sleep(1.0)  # a first delta for CPU and processes, so the cards never open empty
    last_slow, e = 0.0, None
    while True:
        cur = sample()
        now = time.time()
        if e is None or now - last_slow >= slow:
            e = energy(now)
            write_card(out, "energy", card_energy(e, pal, cols["full"]))
            for name, markup in cards_claude(claude(now), pal, now, cols["full"]).items():
                write_card(out, name, markup)
            last_slow = now
        write_card(out, "system", card_system(system(prev, cur, now), e, pal, cols["half"]))
        write_card(out, "apps", card_apps(procs(prev, cur), pal, cols["half"]))
        prev = cur
        if once:
            return 0
        time.sleep(fast)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="observe")
    sub = ap.add_subparsers(dest="cmd", required=True)
    j = sub.add_parser("json")
    j.add_argument("what", choices=["energy", "claude", "system", "procs"])
    lp = sub.add_parser("lock-loop")
    lp.add_argument("--out", required=True)
    lp.add_argument("--palette", required=True, help="a JSON file with the palette's hexes")
    lp.add_argument("--cols", type=int, default=69, help="a full-width card's text width, in body columns")
    lp.add_argument("--half", type=int, default=31, help="a half-width card's text width, in body columns")
    lp.add_argument("--type", help="a JSON file with the lock's font families (TYPE)")
    lp.add_argument("--fast", type=int, default=30)
    lp.add_argument("--slow", type=int, default=60)
    lp.add_argument("--once", action="store_true")
    a = ap.parse_args(argv)
    if a.cmd == "json":
        if a.what in ("energy", "claude"):
            doc = energy() if a.what == "energy" else claude()
        else:
            p = sample()
            time.sleep(1.0)
            c = sample()
            doc = system(p, c) if a.what == "system" else procs(p, c)
        json.dump(doc, sys.stdout)
        return 0
    pal = json.loads(Path(a.palette).read_text())
    if a.type:
        TYPE.update(json.loads(Path(a.type).read_text()))
    cols = {"full": a.cols, "half": a.half}
    return lock_loop(Path(a.out), pal, cols, a.once, a.fast, a.slow)


if __name__ == "__main__":
    sys.exit(main())
