#!/usr/bin/env python3
"""The HOLIDAY REGISTRY: validate it, expand it into dated occurrences, import the UN's
observances, and watch the official sources for changes. Standard library only; the network
part shells out to curl and openssl, which the runners and the dev shell both have.

    registry.py validate  <registry-dir>
    registry.py build     <registry-dir> --from 2024 --to 2032   (JSON on stdout)
    registry.py import-un <un.html> --year 2026 --checked 2026-10-18 > observances-un.json
    registry.py check-sources <registry-dir> [--lock sources.lock.json] [--update-lock]

The model and the rules: docs/notes/desktop/calendar.md
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import html
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

KINDS = {"civil_holiday", "religious_holiday", "optional", "optional_partial", "observance"}
APPLICABILITY = {
    "general",
    "federal_admin",
    "state_admin",
    "municipal_admin",
    "municipal_education",
    "observance",
}
STATUSES = {"verified", "calculated", "pending", "stale", "disputed"}
HOLIDAY_KINDS = {"civil_holiday", "religious_holiday"}


# ── Dates: civil dates only (datetime.date), never a time of day, so no zone or DST can shift one ──
def easter(year: int) -> dt.date:
    """Easter Sunday, Gregorian (the anonymous algorithm, Meeus/Jones/Butcher)."""
    a = year % 19
    b, c = divmod(year, 100)
    d, e = divmod(b, 4)
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i, k = divmod(c, 4)
    weekday = (32 + 2 * e + 2 * i - h - k) % 7  # the algorithm's "L"
    m = (a + 11 * h + 22 * weekday) // 451
    month, day = divmod(h + weekday - 7 * m + 114, 31)
    return dt.date(year, month, day + 1)


def parse_date(s: str) -> dt.date:
    return dt.date.fromisoformat(s)


def in_years(event: dict, year: int) -> bool:
    years = event.get("years", {})
    if "only" in years:
        return year in years["only"]
    return years.get("from", -10**9) <= year <= years.get("to", 10**9)


def dates_of(event: dict, year: int) -> list[dt.date]:
    """The event's dates in a year, empty when it does not fall in it."""
    rule = event["rule"]
    t = rule["type"]
    if t == "fixed":
        if not in_years(event, year):
            return []
        try:
            return [dt.date(year, rule["month"], rule["day"])]
        except ValueError:  # 29/02 in a common year: no occurrence, never a shifted one
            return []
    if t == "easter":
        if not in_years(event, year):
            return []
        return [easter(year) + dt.timedelta(days=rule["offset"])]
    if t == "date":
        d = parse_date(rule["date"])
        return [d] if d.year == year else []
    if t == "range":
        start, end = parse_date(rule["start"]), parse_date(rule["end"])
        out, d = [], start
        while d <= end:
            if d.year == year:
                out.append(d)
            d += dt.timedelta(days=1)
        return out
    raise ValueError(f"unknown rule type {t!r}")


def occurrence_status(event: dict, year: int) -> tuple[str, list[str], dict | None]:
    """How sure a given year's occurrence is, and from which sources.

    A law-based fixed date is the law's own status. An Easter-based or annual one is VERIFIED
    only for a year an act confirmed; otherwise the date is CALCULATED (a law fixes the holiday)
    or PENDING (an annual act must still declare it: an optional day is never assumed).
    """
    confirmed = event.get("confirmed", {}).get(str(year))
    if confirmed is not None:
        return event["status"], confirmed.get("sources", event["sources"]), confirmed.get("partial")
    if event.get("annual_act"):
        return "pending", event["sources"], None
    if event["rule"]["type"] == "easter" and event["status"] == "verified":
        return "calculated", event["sources"], None
    return event["status"], event["sources"], None


def expand(registry: dict, year: int) -> list[dict]:
    out = []
    for e in registry["events"]:
        for d in dates_of(e, year):
            status, sources, partial = occurrence_status(e, year)
            occ = {
                "id": e["id"],
                "date": d.isoformat(),
                "name": e["name"],
                "display": e.get("display", e["name"]),
                "jurisdiction": e["jurisdiction"],
                "kind": e["kind"],
                "applicability": e["applicability"],
                "status": status,
                "verified_at": e.get("verified_at"),
                "basis": e.get("basis", ""),
                "sources": sources,
            }
            p = partial or e.get("partial")
            if p:
                occ["partial"] = p
            if e.get("notes"):
                occ["notes"] = e["notes"]
            out.append(occ)
    # Stable order: by date, then the stronger kind first, then the narrower place.
    rank = {"civil_holiday": 0, "religious_holiday": 0, "optional": 1, "optional_partial": 1, "observance": 2}
    out.sort(key=lambda o: (o["date"], rank[o["kind"]], o["jurisdiction"], o["id"]))
    return out


# ── Validation: the schema, and the rules that keep a guess from looking like a fact ──
def load(regdir: Path) -> dict:
    reg = json.loads((regdir / "holidays.json").read_text(encoding="utf-8"))
    un = regdir / "observances-un.json"
    if un.exists():
        extra = json.loads(un.read_text(encoding="utf-8"))
        reg["sources"].update(extra.get("sources", {}))
        reg["events"] += extra.get("events", [])
    return reg


def validate(reg: dict, today: dt.date | None = None) -> list[str]:
    today = today or dt.date.today()
    errs = []
    ids = set()
    for s_id, s in reg["sources"].items():
        for f in ("title", "url", "authority", "document_id", "checked_at", "check"):
            if not s.get(f):
                errs.append(f"source {s_id}: missing {f}")
        if not str(s.get("url", "")).startswith("https://"):
            errs.append(f"source {s_id}: url must be https")
        if s.get("checked_at") and parse_date(s["checked_at"]) > today:
            errs.append(f"source {s_id}: checked_at in the future")
    for e in reg["events"]:
        i = e.get("id", "?")
        if i in ids:
            errs.append(f"event {i}: duplicate id")
        ids.add(i)
        for f in ("name", "jurisdiction", "kind", "applicability", "rule", "status", "sources"):
            if f not in e:
                errs.append(f"event {i}: missing {f}")
        if e.get("jurisdiction") not in reg["jurisdictions"]:
            errs.append(f"event {i}: unknown jurisdiction {e.get('jurisdiction')}")
        if e.get("kind") not in KINDS:
            errs.append(f"event {i}: unknown kind {e.get('kind')}")
        if e.get("status") not in STATUSES:
            errs.append(f"event {i}: unknown status {e.get('status')}")
        for a in e.get("applicability", []):
            if a not in APPLICABILITY:
                errs.append(f"event {i}: unknown applicability {a}")
        for s in e.get("sources", []) + [x for c in e.get("confirmed", {}).values() for x in c.get("sources", [])]:
            if s not in reg["sources"]:
                errs.append(f"event {i}: unknown source {s}")
        if e.get("status") == "verified":
            if not e.get("sources"):
                errs.append(f"event {i}: verified with no source")
            if not e.get("verified_at"):
                errs.append(f"event {i}: verified with no verified_at")
        if e.get("verified_at") and parse_date(e["verified_at"]) > today:
            errs.append(f"event {i}: verified_at in the future")
        # The legal rules the calendar must never blur.
        kind, appl = e.get("kind"), e.get("applicability", [])
        if kind in {"optional", "optional_partial"} and "general" in appl:
            errs.append(f"event {i}: an optional day never applies to the general population")
        if e.get("jurisdiction") == "UN" and kind != "observance":
            errs.append(f"event {i}: a UN date is an observance, never a Brazilian holiday")
        if kind == "optional_partial" and not (e.get("partial") or any(c.get("partial") for c in e.get("confirmed", {}).values())):
            errs.append(f"event {i}: a partial optional day needs its hours")
        if e.get("annual_act") and e.get("rule", {}).get("type") == "date":
            errs.append(f"event {i}: annual_act is for a recurring rule, a dated act is already its year")
        try:
            dates_of(e, 2026)
        except (KeyError, ValueError) as x:
            errs.append(f"event {i}: bad rule ({x})")
    return errs


def build(reg: dict, y0: int, y1: int) -> dict:
    return {
        "schema_version": reg["schema_version"],
        "years": {str(y): expand(reg, y) for y in range(y0, y1 + 1)},
        "range": [y0, y1],
        "jurisdictions": reg["jurisdictions"],
        "sources": {k: {f: v[f] for f in ("title", "url", "authority", "document_id", "checked_at", "check")} for k, v in reg["sources"].items()},
    }


# ── The UN's list: one page, one row per day, imported as dated observances for the year read ──
ROW = re.compile(
    r'views-field-title">.*?<a href="(?P<page>[^"]+)">(?P<title>.*?)</a>.*?'
    r'(?:views-field-field-url">.*?<a href="(?P<doc>[^"]+)">(?P<res>.*?)</a>.*?)?'
    r'date-display-single">(?P<dd>\d{2}) (?P<mon>[A-Z][a-z]{2})</span>',
    re.S,
)
MONTHS = {m: i for i, m in enumerate("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split(), 1)}


def slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")[:60]


def import_un(page: str, year: int, checked: str) -> dict:
    events, sources, seen = [], {}, set()
    for row in page.split('class="views-row ')[1:]:
        m = ROW.search(row)
        if not m:
            continue
        title = html.unescape(re.sub(r"<[^>]+>", "", m["title"])).strip()
        date = dt.date(year, MONTHS[m["mon"]], int(m["dd"]))
        eid = f"un-{slug(title)}-{date.isoformat()}"  # a day can come twice a year (Migratory Bird Day)
        if eid in seen:
            continue
        seen.add(eid)
        srcs = ["un-observances"]
        if m["doc"] and m["doc"].startswith("http"):
            sid = "un-doc-" + slug(html.unescape(m["res"] or m["doc"]))
            sources[sid] = {
                "title": html.unescape(m["res"] or "").strip() or "UN document",
                "url": m["doc"].replace("http://", "https://", 1),
                "authority": "United Nations",
                "document_id": html.unescape(m["res"] or "").strip() or m["doc"],
                "checked_at": checked,
                "check": "listed",
                "watch": False,
            }
            srcs.append(sid)
        events.append(
            {
                "id": eid,
                "name": title,
                "jurisdiction": "UN",
                "kind": "observance",
                "applicability": ["observance"],
                "rule": {"type": "date", "date": date.isoformat()},
                "status": "verified",
                "verified_at": checked,
                "basis": "UN observance, as listed for " + str(year),
                "sources": srcs,
            }
        )
    return {"sources": sources, "events": events}


# ── Watching the sources: a fingerprint of each page's TEXT, never an automatic verdict ──
def fetch(url: str) -> bytes:
    """GET with curl. A server that omits its intermediate certificate (São Carlos does) gets it
    fetched from the leaf's AIA field, the way a browser does, and the chain is still verified."""
    # A browser-shaped agent that still names the project: Planalto resets a connection otherwise.
    ua = "Mozilla/5.0 (compatible; dotfiles-holiday-registry; +https://github.com/v1cferr/dotfiles)"
    cmd = ["curl", "-sSL", "--fail", "--max-time", "60", "-A", ua]
    r = subprocess.run(cmd + [url], capture_output=True)
    if r.returncode == 0:
        return r.stdout
    if r.returncode != 60:  # anything but "unable to get local issuer certificate"
        raise RuntimeError(f"curl exit {r.returncode}: {r.stderr.decode(errors='replace').strip()}")
    host = re.match(r"https://([^/]+)", url)[1]
    leaf = subprocess.run(
        ["openssl", "s_client", "-connect", f"{host}:443", "-servername", host],
        input=b"", capture_output=True, timeout=60,
    ).stdout
    pem = re.search(rb"-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----", leaf, re.S)
    if not pem:
        raise RuntimeError("no certificate from the server")
    text = subprocess.run(["openssl", "x509", "-noout", "-text"], input=pem[0], capture_output=True).stdout.decode()
    aia = re.search(r"CA Issuers - URI:(\S+)", text)
    if not aia:
        raise RuntimeError("no AIA issuer URL")
    der = subprocess.run(["curl", "-sS", "--fail", "--max-time", "30", aia[1]], capture_output=True, check=True).stdout
    issuer = subprocess.run(["openssl", "x509", "-inform", "der"], input=der, capture_output=True, check=True).stdout
    system = next((p for p in ("/etc/ssl/certs/ca-certificates.crt", "/etc/ssl/cert.pem") if Path(p).exists()), None)
    with tempfile.NamedTemporaryFile("wb", suffix=".pem", delete=False) as f:
        f.write(issuer + (Path(system).read_bytes() if system else b""))
        bundle = f.name
    r = subprocess.run(cmd + ["--cacert", bundle, url], capture_output=True)
    Path(bundle).unlink(missing_ok=True)
    if r.returncode != 0:
        raise RuntimeError(f"curl exit {r.returncode} after AIA: {r.stderr.decode(errors='replace').strip()}")
    return r.stdout


def fingerprint(body: bytes, between: list[str] | None = None) -> str:
    """The TEXT's hash: markup, scripts and whitespace out, so a redesign of the page around the
    same words does not read as a legal change; `between` narrows it to the stretch that holds the
    data (a portal's menus change weekly). A PDF is hashed as bytes."""
    if body[:5] == b"%PDF-":
        return "sha256:" + hashlib.sha256(body).hexdigest()
    t = body.decode("utf-8", errors="replace")
    t = re.sub(r"(?is)<(script|style|nav|header|footer|form)\b.*?</\1>", " ", t)
    t = re.sub(r"(?s)<!--.*?-->", " ", t)
    t = html.unescape(re.sub(r"<[^>]+>", " ", t))
    t = re.sub(r"\s+", " ", t).strip()
    if between:
        i, j = t.find(between[0]), t.find(between[1])
        if i < 0 or j <= i:
            return "markers-missing"  # the page changed shape: a human must look
        t = t[i:j]
    return "sha256:" + hashlib.sha256(t.encode()).hexdigest()


def check_sources(reg: dict, lock: dict, today: str) -> tuple[dict, list[dict]]:
    new, report = dict(lock), []
    for sid, s in sorted(reg["sources"].items()):
        if not s.get("watch"):
            continue
        url = s.get("fetch_url", s["url"])
        before = lock.get(sid, {})
        try:
            fp = fingerprint(fetch(url), s.get("watch_between"))
        except Exception as x:  # unreachable: report it, keep the last known fingerprint
            report.append({"source": sid, "state": "unreachable", "detail": str(x)[:300], "url": url})
            continue
        state = "new" if not before else ("unchanged" if before.get("fingerprint") == fp else "changed")
        report.append({"source": sid, "state": state, "url": url})
        new[sid] = {"fingerprint": fp, "seen_at": today if state != "unchanged" else before.get("seen_at", today)}
    return new, report


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    v = sub.add_parser("validate")
    v.add_argument("regdir", type=Path)
    b = sub.add_parser("build")
    b.add_argument("regdir", type=Path)
    b.add_argument("--from", dest="y0", type=int, required=True)
    b.add_argument("--to", dest="y1", type=int, required=True)
    u = sub.add_parser("import-un")
    u.add_argument("page", type=Path)
    u.add_argument("--year", type=int, required=True)
    u.add_argument("--checked", required=True)
    c = sub.add_parser("check-sources")
    c.add_argument("regdir", type=Path)
    c.add_argument("--lock", type=Path, required=True)
    c.add_argument("--update-lock", action="store_true")
    c.add_argument("--report", type=Path)
    a = ap.parse_args(argv)

    if a.cmd == "validate":
        errs = validate(load(a.regdir))
        for e in errs:
            print("error:", e, file=sys.stderr)
        print(f"{'FAIL' if errs else 'ok'}: {len(errs)} error(s)")
        return 1 if errs else 0
    if a.cmd == "build":
        reg = load(a.regdir)
        errs = validate(reg, today=dt.date.max)  # the build is pure: no clock inside a derivation
        if errs:
            print("\n".join(errs), file=sys.stderr)
            return 1
        json.dump(build(reg, a.y0, a.y1), sys.stdout, ensure_ascii=False, separators=(",", ":"))
        return 0
    if a.cmd == "import-un":
        out = import_un(a.page.read_text(encoding="utf-8"), a.year, a.checked)
        json.dump(out, sys.stdout, ensure_ascii=False, indent=2)
        print()
        print(f"{len(out['events'])} observances", file=sys.stderr)
        return 0 if out["events"] else 1
    if a.cmd == "check-sources":
        lock = json.loads(a.lock.read_text()) if a.lock.exists() else {}
        new, report = check_sources(load(a.regdir), lock, dt.date.today().isoformat())
        lines = ["| Source | State | URL |", "| --- | --- | --- |"]
        lines += [f"| `{r['source']}` | {r['state']}{' (' + r['detail'] + ')' if r.get('detail') else ''} | {r['url']} |" for r in report]
        text = "\n".join(lines) + "\n"
        print(text)
        if a.report:
            a.report.write_text(text)
        if a.update_lock:
            a.lock.write_text(json.dumps(new, indent=2, sort_keys=True) + "\n")
        # Exit 2 when a human must look: a change or an unreachable source. Nothing is rewritten.
        return 2 if any(r["state"] in ("changed", "unreachable") for r in report) else 0
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
