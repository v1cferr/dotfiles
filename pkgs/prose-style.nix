# prose-style: it fails on rule 17's mechanical bans, in the tree and in the commit message. What
# counts as prose, and why the naive version is wrong: docs/notes/repo/prose-style.md
{ writers }:

writers.writePython3Bin "prose-style"
  {
    libraries = [ ];
    flakeIgnore = [ "E501" ]; # the repo's line length is 100, not flake8's 79
  }
  ''
    """Fail on rule 17's mechanical bans: an em dash, an emoji or a shared authorship."""
    import os
    import re
    import subprocess
    import sys

    # The repo root, so the check runs the same from any cwd and inside a nix build.
    ROOT = os.environ.get("PROSE_STYLE_ROOT") or subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()

    # Every codepoint is an ESCAPE and this file stays pure ASCII on purpose: a checker that carries
    # the glyph it forbids is a checker that can flag itself the day the stripping rules change.
    EM_DASH = "\u2014"

    # EMOJI AS DECORATION, and the class is deliberately narrow: the pictographic planes, the three
    # status markers (white heavy check, cross mark, warning sign) and VS16, which is what an emoji
    # picker appends. The BMP symbols this repo quotes as LITERALS stay out: U+2713 from
    # `sbctl status`, and the bare U+2764 the august history discusses.
    EMOJI = re.compile("[\U0001F000-\U0001FAFF\u2705\u274C\u26A0]|\uFE0F")

    # A comment opener per extension: after the marker it is prose, before it it is code.
    MARKERS = {
        ".nix": ["#"],
        ".sh": ["#"],
        ".py": ["#"],
        ".yaml": ["#"],
        ".yml": ["#"],
        ".toml": ["#"],
        ".lua": ["--"],
        ".qml": ["//"],
        ".js": ["//"],
        ".json": ["//"],
        ".jsonc": ["//"],
    }
    # Files with no extension that are still code carrying comments.
    BY_NAME = {".envrc": ["#"]}

    FENCE = re.compile(r"^\s*(```|~~~)")
    CODESPAN = re.compile(r"`[^`]*`")
    # In PROSE only a quoted GLYPH is a literal, so `"no value"` is a phrase and stays checked.
    QUOTED_GLYPH = re.compile(r'"[^"\s]{1,3}"')
    # In a COMMENT any quoted span is a literal. That is also what keeps a hex color from being
    # read as the start of a `#` comment.
    QUOTED = re.compile(r'"[^"]*"')
    # A table cell whose WHOLE content is the em dash is the "no value" glyph, not prose.
    EMPTY_CELL = re.compile(r"(?<=\|)\s*" + EM_DASH + r"\s*(?=\|)")
    COAUTHOR = re.compile(r"^\s*co-authored-by\s*:", re.IGNORECASE)

    # A tracked exception needs a REASON, so it lands in the diff instead of rotting in silence.
    # Keyed by (path, line). Emptying this is the goal, not growing it.
    ALLOWED = {}


    def prose_lines(rel, text):
        """Yield (lineno, prose) for one file, with the literals already removed."""
        ext = os.path.splitext(rel)[1]
        markers = MARKERS.get(ext) or BY_NAME.get(os.path.basename(rel))

        if rel.endswith(".md"):
            fenced = False
            for n, line in enumerate(text.splitlines(), 1):
                if FENCE.match(line):
                    fenced = not fenced
                    continue
                if fenced:
                    continue
                line = CODESPAN.sub("", line)
                line = QUOTED_GLYPH.sub("", line)
                line = EMPTY_CELL.sub("", line)
                yield n, line
            return

        if not markers:
            return

        for n, line in enumerate(text.splitlines(), 1):
            line = QUOTED.sub("", CODESPAN.sub("", line))
            cut = [line.find(m) for m in markers if line.find(m) >= 0]
            if cut:
                yield n, line[min(cut):]


    def find(where, lines):
        out = []
        for n, prose in lines:
            if (where, n) in ALLOWED:
                continue
            if EM_DASH in prose:
                out.append((where, n, "em dash in prose", prose.strip()))
            hit = EMOJI.search(prose)
            if hit:
                out.append((where, n, f"emoji U+{ord(hit.group()[0]):04X}", prose.strip()))
        return out


    def tracked():
        out = subprocess.run(
            ["git", "-C", ROOT, "ls-files"],
            capture_output=True, text=True, check=True,
        ).stdout.split()
        return [f for f in out if os.path.isfile(os.path.join(ROOT, f))]


    def commit_msg(path):
        """The message the commit is about to carry, minus git's own comment lines."""
        body = [
            (n, line)
            for n, line in enumerate(open(path, encoding="utf-8").read().splitlines(), 1)
            if not line.startswith("#")
        ]
        trailers = [
            ("commit message", n, "Co-Authored-By trailer", line.strip())
            for n, line in body if COAUTHOR.match(line)
        ]
        clean = [(n, QUOTED.sub("", CODESPAN.sub("", line))) for n, line in body]
        return trailers + find("commit message", clean)


    def report(found, what):
        if found:
            print(f"prose-style: {len(found)} finding(s) in {what}\n", file=sys.stderr)
            for where, n, kind, line in found:
                print(f"  {where}:{n}: {kind}", file=sys.stderr)
                print(f"    {line[:96]}", file=sys.stderr)
            print("\nRule 17: no em dash, no emoji, no shared authorship. A LITERAL being quoted"
                  " is the exception; see docs/rules.md.", file=sys.stderr)
            return 1

        print(f"prose-style: {what}, clean")
        return 0


    def main():
        if len(sys.argv) > 1 and sys.argv[1] == "--commit-msg":
            if len(sys.argv) < 3:
                print("prose-style: --commit-msg needs the message file", file=sys.stderr)
                return 2
            return report(commit_msg(sys.argv[2]), "commit message")

        found = []
        files = 0
        for rel in tracked():
            try:
                text = open(os.path.join(ROOT, rel), encoding="utf-8").read()
            except (UnicodeDecodeError, OSError):
                continue
            lines = list(prose_lines(rel, text))
            if lines:
                files += 1
                found += find(rel, lines)
        return report(found, f"{files} files of prose")


    sys.exit(main())
  ''
