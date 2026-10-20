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
BLOCKS = "▁▂▃▄▅▆▇█"


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


def claude(now: float | None = None) -> dict:
    now = now or time.time()
    out = {"source": "glance-feed:claude_usage", "unit": "%", "status": "missing", "account": "FAI",
           "timestamp": None, "age": None, "error": None, "session": {"pct": None, "resets": None},
           "weekly": {"pct": None, "resets": None}, "history": {"s": [], "w": []}}
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
    # 24 hourly points, each the last value KNOWN at that hour; before the first sample, a hole.
    hist = sorted((h for h in doc.get("history") or [] if isinstance(h, dict) and "ts" in h),
                  key=lambda h: h["ts"])
    for key in ("s", "w"):
        series, j, v = [], 0, None
        for k in range(24):
            t = now - (23 - k) * 3600
            while j < len(hist) and hist[j]["ts"] <= t:
                x = hist[j].get(key)
                v = None if x is None else float(x)
                j += 1
            series.append(v)
        out["history"][key] = series
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


def spark(series: list, top: float, color: str, hole: str) -> str:
    """Block characters on a ZERO-based scale; a missing point is a dim dot, never a low bar."""
    out = []
    for v in series:
        if v is None:
            out.append(f'<span foreground="#{hole}">·</span>')
        else:
            i = 0 if top <= 0 else min(7, max(0, round(v / top * 7)))
            out.append(BLOCKS[i])
    return f'<span foreground="#{color}">' + "".join(out) + "</span>"


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


SPARK_PT = 16  # the 24 h strips' size, the body's
BODY_PT = 14  # the panel's running text: --cols counts columns at this size
# The lock's type (default.nix passes the same with --type): families for numbers, icons and charts.
TYPE = {"display": "Geist", "data": "Geist Mono", "icons": "Material Symbols Rounded", "iconWeight": 300,
        "chart": "Sparks Dot-line Thick,"}
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


def hero(text: str, pt: int, color: str = "", weight: int = 200) -> str:
    """The section's number in the display face: large and LIGHT, so size and not weight carries it."""
    fg = f' foreground="#{color}"' if color else ""
    return f'<span font_family="{TYPE["display"]}" size="{pt * 1024}" font_weight="{weight}"{fg}>{text}</span>'


def caps(text: str, color: str) -> str:
    """A small tracked label in caps: what the number above it is."""
    return f'<span size="{11 * 1024}" letter_spacing="2048" foreground="#{color}"><b>{esc(text.upper())}</b></span>'


def meta(text: str, color: str) -> str:
    return f'<span size="{12 * 1024}" foreground="#{color}">{text}</span>'


def meter(frac, cols: int, color: str, track: str) -> str:
    """A thin bar, filled in the section's color over a dim track: a share you read without a number."""
    if frac is None:
        return f'<span foreground="#{track}">' + "━" * cols + "</span>"
    n = max(0, min(cols, round(frac * cols)))
    return f'<span foreground="#{color}">' + "━" * n + f'</span><span foreground="#{track}">' + "━" * (cols - n) + "</span>"


def spark2(series: list, top: float, color: str, hole: str, pt: int = SPARK_PT) -> str:
    """Two rows of blocks, 16 levels on a ZERO-based scale; a hole is a dim dot on the floor."""
    up, down = [], []
    for v in series:
        if v is None:
            up.append(" ")
            down.append(f'<span foreground="#{hole}">·</span>')
            continue
        lvl = 0 if top <= 0 else max(1, min(16, round(v / top * 16)))
        down.append(BLOCKS[min(8, lvl) - 1])
        up.append(BLOCKS[lvl - 9] if lvl > 8 else " ")
    sz = pt * 1024
    return (f'<span size="{sz}" foreground="#{color}">' + "".join(up) + "</span>\n"
            f'<span size="{sz}" foreground="#{color}">' + "".join(down) + "</span>")


def card_energy(e: dict, pal: dict, cols: int = 70) -> str:
    """The hero watts, the 30 min chart across the whole width, the CPU/GPU split, one meta line."""
    sub, dim, tone = pal["subtext"], pal["dim"], pal["orange"]
    if e["status"] == "missing" or e.get("measured_w") is None:
        return meta("Sem medições do power-log", sub)
    peak = max([v for v in e["history"] if v is not None] or [1])
    top = -(-peak // 25) * 25  # a round ceiling over the peak, so the bars read as levels, not a block
    tot = e["measured_w"] or 1
    half = cols // 2

    def share(name, w):
        head = f"{name}  {w:5.1f} W  "
        return f'<span foreground="#{sub}">{head}</span>' + meter(w / tot, half - len(head) - 3, tone, dim)

    when = ago(e["age"])
    notes = ["30 min", f"0 a {top:.0f} W", f"pico {peak:.0f} W"]
    if e["baseline"]:
        notes.append(f'repouso Eco {e["baseline"]["median_w"]:.0f} W')
    notes.append(PROFILE.get(e["profile"] or "", e["profile"] or "–"))
    if e["status"] == "stale":
        notes.insert(0, "DESATUALIZADO")
    if when != "agora":
        notes.append(when)
    return "\n".join([
        hero(f'{e["measured_w"]:.0f}', 72) + hero(" W", 24, sub, 300) + "   " + meta("CPU + GPU medido", sub),
        spark2(e["history"], top, tone, dim, cols * BODY_PT // 30),
        share("CPU", e["cpu_w"]) + "   " + share("GPU", e["gpu_w"]),
        meta(" · ".join(notes), sub),
    ])


def cards_claude(c: dict, pal: dict, now: float, cols: int = 30) -> dict:
    """The 5 h session and the week, one half each: a ring, the share, its reset, the last 24 h."""
    sub, dim = pal["subtext"], pal["dim"]
    if c["status"] in ("missing", "error"):
        why = {"no-credentials": "sem login da conta FAI"}.get(c.get("error"), c.get("error") or "sem dados")
        return {"claude-s": meta(esc(why), sub), "claude-w": ""}

    def half(cap, w, tone, hist):
        pct = w["pct"]
        ring, full = ring_glyph(pct)
        reset = f'reinicia em {until(w["resets"], now)}' if w["resets"] else "sem janela aberta"
        if c["status"] == "stale":
            reset = "DESATUALIZADO · " + reset
        return "\n".join([
            icon(ring, 38, tone, full) + "  " + hero("–" if pct is None else f"{round(pct)}%", 44),
            caps(cap, sub),
            meta(reset, sub),
            spark(hist[-cols:], 100, tone, dim),
        ])

    return {
        "claude-s": half("sessão · 5 h", c["session"], pal["orange"], c["history"]["s"]),
        "claude-w": half("semana", c["weekly"], pal["magenta"], c["history"]["w"]),
    }


def cards_system(s: dict, e: dict, pal: dict, cols: int = 21) -> dict:
    """CPU, RAM and GPU as three equal columns: the number, what it is, a meter, one note."""
    sub, dim, tone = pal["subtext"], pal["dim"], pal["blue"]
    m = s.get("mem") or {}
    g = s.get("gpu") or {}
    t = (e or {}).get("temps") or {}
    temp = lambda k: "–" if t.get(k) is None else f"{t[k]:.0f}°"  # noqa: E731
    bar = cols - 3

    def col(value, cap, frac, note):
        return "\n".join([hero(value, 36), caps(cap, sub), meter(frac, bar, tone, dim), meta(note, sub)])

    cpu = s.get("cpu_pct")
    busy = None if g.get("render_idle_pct") is None else 100 - g["render_idle_pct"]
    return {
        "sys-cpu": col("–" if cpu is None else f"{cpu:.0f}%", "CPU", None if cpu is None else cpu / 100,
                       f'{temp("cpu_c")} · NVMe {temp("nvme_c")}'),
        "sys-ram": col(fmt_bytes(m.get("used")), "RAM", m["used"] / m["total"] if m.get("total") else None,
                       f'livre {fmt_bytes(m.get("available"))}'),
        "sys-gpu": col("–" if g.get("board_w") is None else f'{g["board_w"]:.0f} W', "GPU",
                       None if busy is None else busy / 100,
                       f'{temp("gpu_c")} · render {"–" if busy is None else f"{busy:.0f}%"}'),
    }


def card_apps(p: dict, pal: dict, cols: int = 70) -> str:
    """The three apps using the most CPU now, grouped by app: a name, a meter, the share."""
    sub, dim, tone = pal["subtext"], pal["dim"], pal["blue"]
    name_w, val_w = 16, 7
    bar = cols - name_w - val_w - 2
    lines = [caps("mais CPU agora · % de um núcleo", sub)]
    items = p["cpu"][:3]
    if not items:
        return "\n".join(lines + [meta("–", sub)])
    topv = max(i["value"] for i in items) or 1
    # Padded BEFORE escaping, so an `&` in a name never shifts the column.
    lines += [esc(fit(i["name"], name_w).ljust(name_w)) + " " + meter(i["value"] / topv, bar, tone, dim)
              + f'<span foreground="#{sub}">{f"{i['value']:.0f}%":>{val_w}}</span>' for i in items]
    return "\n".join(lines)


def write_card(out: Path, name: str, markup: str) -> None:
    """`pid\\nepoch\\nmarkup`, atomically: the label shows it only while this writer is alive."""
    tmp = out / f".{name}.{os.getpid()}"
    tmp.write_text(f"{os.getpid()}\n{int(time.time())}\n{markup}")
    os.replace(tmp, out / name)


def lock_loop(out: Path, pal: dict, cols: dict, once: bool, fast: int, slow: int) -> int:
    out.mkdir(parents=True, exist_ok=True)
    prev = sample()
    time.sleep(1.0)  # a first delta for CPU and processes, so the sections never open empty
    last_slow, e = 0.0, None
    while True:
        cur = sample()
        now = time.time()
        if e is None or now - last_slow >= slow:
            e = energy(now)
            write_card(out, "energy", card_energy(e, pal, cols["full"]))
            for name, markup in cards_claude(claude(now), pal, now, cols["half"]).items():
                write_card(out, name, markup)
            last_slow = now
        for name, markup in cards_system(system(prev, cur, now), e, pal, cols["third"]).items():
            write_card(out, name, markup)
        write_card(out, "apps", card_apps(procs(prev, cur), pal, cols["full"]))
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
    lp.add_argument("--cols", type=int, default=70, help="the panel's full width, in body columns")
    lp.add_argument("--half", type=int, default=30, help="a half's width, in body columns")
    lp.add_argument("--third", type=int, default=21, help="a third's width, in body columns")
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
    cols = {"full": a.cols, "half": a.half, "third": a.third}
    return lock_loop(Path(a.out), pal, cols, a.once, a.fast, a.slow)


if __name__ == "__main__":
    sys.exit(main())
