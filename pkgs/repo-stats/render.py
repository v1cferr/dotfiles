"""Draw the README's badges and stats card from scc's JSON and the flake's own facts."""

import json
import os
import re
import sys
from html import escape

# The profile README's palette (github.com/v1cferr/v1cferr), so the two pages read as one.
PANEL, EDGE, DIM, FG, NIX, LABEL = "#0d1117", "#30363d", "#8b949e", "#c9d1d9", "#7ebae4", "#161b22"
MONO = 'ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace'
# Monospace advance is 0.6em in every font on that list, which is what makes a width computable.
ADVANCE = 0.6

# Linguist's hues, lifted where the original disappears on a dark panel (Lua, JSON).
COLORS = {
    "Markdown": "#a371f7", "Nix": NIX, "QML": "#44a51c", "TypeScript": "#3178c6",
    "JSON": "#cbcb41", "YAML": "#cb4b4b", "Lua": "#6c78d6", "Python": "#3572a5",
    "Shell": "#89e051", "Patch": "#b07219",
}
OTHER = "#6e7681"
TOP = 6


def human(n):
    return f"{n / 1000:.1f}k" if n >= 1000 else str(n)


def badge(label, value):
    size, pad, height = 11, 8, 22
    lw = round(len(label) * size * ADVANCE) + 2 * pad
    vw = round(len(value) * size * ADVANCE) + 2 * pad
    w = lw + vw
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{height}" role="img" aria-label="{escape(label)}: {escape(value)}">
  <title>{escape(label)}: {escape(value)}</title>
  <clipPath id="r"><rect width="{w}" height="{height}" rx="4"/></clipPath>
  <g clip-path="url(#r)">
    <rect width="{lw}" height="{height}" fill="{LABEL}"/>
    <rect x="{lw}" width="{vw}" height="{height}" fill="{PANEL}"/>
  </g>
  <rect x="0.5" y="0.5" width="{w - 1}" height="{height - 1}" rx="4" fill="none" stroke="{EDGE}"/>
  <g font-family='{MONO}' font-size="{size}">
    <text x="{pad}" y="15" fill="{DIM}">{escape(label)}</text>
    <text x="{lw + pad}" y="15" fill="{NIX}">{escape(value)}</text>
  </g>
</svg>
"""


def card(langs, stats):
    w, h, x0, bar_w = 880, 250, 40, 800
    cells = [
        (human(stats["code"]), "lines of code"),
        (str(stats["languages"]), "languages"),
        (str(stats["modules"]), "nix files"),
        (str(stats["rules"]), "rules"),
        (str(stats["hooks"]), "gate hooks"),
        (str(stats["pages"]), "doc pages"),
    ]
    step = bar_w / len(cells)
    numbers = "\n".join(
        f'    <text x="{x0 + i * step:.0f}" y="112" font-size="28" fill="{FG}">{escape(v)}'
        f'<animate attributeName="opacity" values="0;1" dur="0.6s" begin="{0.1 * i:.1f}s" fill="freeze"/></text>\n'
        f'    <text x="{x0 + i * step:.0f}" y="134" font-size="12" fill="{DIM}">{escape(c)}</text>'
        for i, (v, c) in enumerate(cells)
    )

    # The bar: one segment per top language, the rest folded into "other", each growing in turn.
    total = sum(lang["Code"] for lang in langs)
    top = langs[:TOP]
    parts = [(lang["Name"], lang["Code"], COLORS.get(lang["Name"], OTHER)) for lang in top]
    rest = total - sum(p[1] for p in parts)
    if rest:
        parts.append(("other", rest, OTHER))
    x, segs, legend = float(x0), [], []
    for i, (name, code, color) in enumerate(parts):
        sw = bar_w * code / total
        segs.append(
            f'    <rect x="{x:.1f}" y="162" height="10" width="0" fill="{color}">'
            f'<animate attributeName="width" from="0" to="{sw:.1f}" dur="0.5s" begin="{0.6 + 0.15 * i:.2f}s" fill="freeze"/></rect>'
        )
        x += sw
        lx = x0 + (i % 4) * (bar_w / 4)
        ly = 200 + (i // 4) * 22
        legend.append(
            f'    <circle cx="{lx + 5:.0f}" cy="{ly - 4}" r="4" fill="{color}"/>'
            f'<text x="{lx + 16:.0f}" y="{ly}" font-size="12" fill="{FG}">{escape(name)} '
            f'<tspan fill="{DIM}">{100 * code / total:.1f}%</tspan></text>'
        )
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" role="img"
     aria-label="{stats['code']:,} lines of code in {stats['languages']} languages, {stats['rules']} rules, {stats['hooks']} gate hooks.">
  <title>dotfiles, measured at build</title>
  <rect x="0.5" y="0.5" width="{w - 1}" height="{h - 1}" rx="12" fill="{PANEL}" stroke="{EDGE}"/>
  <g font-family='{MONO}'>
    <text x="{x0}" y="46" font-size="13" fill="{NIX}">nix build .#repo-stats</text>
    <text x="{w - x0}" y="46" font-size="13" fill="{DIM}" text-anchor="end">{escape(stats['release'])} · {escape(stats['date'])}</text>
    <line x1="{x0}" y1="62" x2="{w - x0}" y2="62" stroke="{EDGE}"/>
{numbers}
    <clipPath id="bar"><rect x="{x0}" y="162" width="{bar_w}" height="10" rx="5"/></clipPath>
    <rect x="{x0}" y="162" width="{bar_w}" height="10" rx="5" fill="{LABEL}"/>
    <g clip-path="url(#bar)">
{chr(10).join(segs)}
    </g>
{chr(10).join(legend)}
  </g>
</svg>
"""


def main():
    scc_path, facts_path, src, out = sys.argv[1:]
    langs = sorted(json.load(open(scc_path)), key=lambda lang: -lang["Code"])
    facts = json.load(open(facts_path))
    rules = open(os.path.join(src, "docs/rules.md")).read()
    stats = {
        "code": sum(lang["Code"] for lang in langs),
        "languages": len(langs),
        "modules": next(lang["Count"] for lang in langs if lang["Name"] == "Nix"),
        # A rule is a numbered quote line; a struck-through one still holds its number (rules.md).
        "rules": len(re.findall(r"^> \d+\. ", rules, re.M)),
        "pages": sum(f.endswith(".md") for _, _, fs in os.walk(os.path.join(src, "docs")) for f in fs),
        **facts,
        # lastModifiedDate is YYYYMMDDHHMMSS, the commit's own date and not the build's.
        "date": f"{facts['date'][:4]}-{facts['date'][4:6]}-{facts['date'][6:8]}",
    }
    badges = {
        "loc": ("lines of code", human(stats["code"])),
        "nixos": ("nixos", stats["release"].removeprefix("nixos-")),
        "rules": ("rules", str(stats["rules"])),
        "hooks": ("gate", f"{stats['hooks']} hooks"),
        "inputs": ("flake inputs", str(stats["inputs"])),
        "docs": ("docs", f"{stats['pages']} pages"),
        "updated": ("updated", stats["date"]),
        "license": ("license", "MIT + CC BY 4.0"),
    }
    for name, (label, value) in badges.items():
        open(os.path.join(out, f"{name}.svg"), "w").write(badge(label, value))
    open(os.path.join(out, "card.svg"), "w").write(card(langs, stats))
    langs_out = [{k: lang[k] for k in ("Name", "Count", "Code", "Comment", "Lines")} for lang in langs]
    json.dump({**stats, "byLanguage": langs_out}, open(os.path.join(out, "stats.json"), "w"), indent=2)


main()
