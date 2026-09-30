# rules-index: it fails when the tree cites a rule that does not exist or was retired, and reports
# which rules nothing enforces. The numbering is API (512 citations): docs/notes/repo/rules-index.md
{ writers }:

writers.writePython3Bin "rules-index"
  {
    libraries = [ ];
    flakeIgnore = [ "E501" ]; # the repo's line length is 100, not flake8's 79
  }
  ''
    """Resolve every `rule N` in the tree against docs/rules.md."""
    import os
    import re
    import subprocess
    import sys

    ROOT = os.environ.get("RULES_INDEX_ROOT") or subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()

    RULES = "docs/rules.md"
    # The history is a diary: a citation there is right about the day it was written, forever.
    FROZEN = "docs/history/"
    # `rule 11`, `rules 14 and 15`, `rules 1, 3 and 7`: every number in the run is a citation. A
    # number followed by `/` is a date (`rule 22, 29/09/2026`), so it ends the run instead.
    CITE = re.compile(r"\b[Rr]ules? (\d{1,3}(?![\d/])(?:(?:, | and | or )\d{1,3}(?![\d/]))*)")
    # A rule is a `## N. Title` heading; a retired one keeps its number and strikes it: `## N. ~~`.
    RULE = re.compile(r"^## (\d+)\. (~~)?", re.M)
    # A card names what enforces it; a rule without the line is enforced by memory alone.
    ENFORCED = re.compile(r"^\*\*Enforced by\*\*: (.+)$", re.M)


    def rules():
        text = open(os.path.join(ROOT, RULES)).read()
        found = {int(m[1]): bool(m[2]) for m in RULE.finditer(text)}
        # Each card runs from its number to the next one; the enforcement line is inside it.
        bounds = [m.start() for m in RULE.finditer(text)] + [len(text)]
        enforced = {}
        for (n, _), start, end in zip(RULE.findall(text), bounds, bounds[1:]):
            m = ENFORCED.search(text[start:end])
            enforced[int(n)] = m[1].strip() if m else None
        return found, enforced


    def main():
        found, enforced = rules()
        files = subprocess.run(["git", "-C", ROOT, "ls-files"], capture_output=True, text=True, check=True).stdout.split()
        bad = []
        for f in files:
            if f.startswith(FROZEN) or f == RULES or not os.path.isfile(os.path.join(ROOT, f)):
                continue
            try:
                text = open(os.path.join(ROOT, f)).read()
            except UnicodeDecodeError:
                continue
            for lineno, line in enumerate(text.splitlines(), 1):
                # Inside backticks it is a quoted literal, the repo's standing exception (rule 17).
                for m in CITE.finditer(re.sub(r"`[^`]*`", "", line)):
                    for n in map(int, re.findall(r"\d+", m[1])):
                        if n not in found:
                            bad.append(f"{f}:{lineno}: rule {n} does not exist")
                        elif found[n]:
                            bad.append(f"{f}:{lineno}: rule {n} is retired")

        live = [n for n, retired in sorted(found.items()) if not retired]
        memory = [n for n in live if not enforced.get(n) or enforced[n].lower().startswith("review")]
        print(f"rules-index: {len(live)} live rules, {len(live) - len(memory)} enforced by a check, "
              f"{len(memory)} by review alone: {', '.join(map(str, memory)) or 'none'}")
        if bad:
            print("\n".join(bad), file=sys.stderr)
            print(f"\nrules-index: {len(bad)} citations point at no live rule", file=sys.stderr)
            return 1
        return 0


    sys.exit(main())
  ''
