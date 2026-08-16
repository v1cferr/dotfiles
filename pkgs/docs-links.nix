# docs-links: it fails when a docs/ pointer does not resolve. Rule 16 says a stale note is a bug,
# and until this existed nothing enforced it. What it checks: docs/notes/repo/link-checker.md
{ writers }:

writers.writePython3Bin "docs-links"
  {
    libraries = [ ];
    flakeIgnore = [ "E501" ]; # the repo's line length is 100, not flake8's 79
  }
  ''
    """Verify every docs/ pointer in this repo resolves to a file that exists."""
    import os
    import re
    import subprocess
    import sys

    # The repo root, so the check runs the same from any cwd and inside a nix build.
    ROOT = os.environ.get("DOCS_LINKS_ROOT") or subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()

    CODE_EXT = (".nix", ".lua", ".qml", ".sh", ".toml", ".yaml", ".yml")

    # A bare `docs/...` path written inside code or prose, the form the 2-line headers use.
    POINTER = re.compile(r"\bdocs/[A-Za-z0-9_./-]+\.md\b")
    # A repo path inside backticks. The leading `(?<![:\w/])` keeps `Foundry:hosts/...` out, which
    # is how a path in another repo is written so it does not read as one of ours.
    PROSEPATH = re.compile(
        r"`(?<![:\w/])((?:system|home|pkgs|hosts|scripts|secrets|ci|router)"
        r"/[A-Za-z0-9_./-]+\.(?:nix|sh|py|lua|qml|json|txt|conf|yaml))`"
    )

    # A markdown link. Only relative targets matter: http(s) and #anchors are out of scope.
    MDLINK = re.compile(r"\]\(([^)\s#]+\.(?:md|nix|lua|qml|sh|toml|yaml|yml))(?:#[^)]*)?\)")


    def tracked():
        out = subprocess.run(
            ["git", "-C", ROOT, "ls-files"],
            capture_output=True, text=True, check=True,
        ).stdout.split()
        return [f for f in out if os.path.isfile(os.path.join(ROOT, f))]


    def main():
        broken = []
        checked = 0
        for rel in tracked():
            path = os.path.join(ROOT, rel)
            try:
                text = open(path, encoding="utf-8").read()
            except (UnicodeDecodeError, OSError):
                continue

            # 1. Bare docs/ pointers: CODE ONLY, which is where the 2-line headers put them.
            # A bare path inside markdown is PROSE, not a pointer. Checking it would flag
            # rules.md for citing the OLD pt-BR name of a file it renamed, which is history and
            # correct. In markdown only a real `](target)` link counts, below.
            if rel.endswith(CODE_EXT):
                for target in POINTER.findall(text):
                    # A placeholder like docs/notes/<module>.md documents the CONVENTION.
                    if "<" in target or "*" in target:
                        continue
                    checked += 1
                    if not os.path.isfile(os.path.join(ROOT, target)):
                        broken.append((rel, target, "pointer"))

            # 2. A repo path quoted in prose, in docs that describe the PRESENT. `docs/history/`
            # is exempt: it is a diary, so it names files that were deleted on purpose, and
            # editing it to keep paths alive would stop it being evidence. A path belonging to
            # SOMEBODY ELSE'S repo is written `Repo:path/to/file`, which does not match here.
            if rel.endswith(".md") and not rel.startswith("docs/history/"):
                for target in PROSEPATH.findall(text):
                    checked += 1
                    if not os.path.isfile(os.path.join(ROOT, target)):
                        broken.append((rel, target, "prose path"))

            # 3. Relative markdown links, resolved against the file's own directory.
            if rel.endswith(".md"):
                base = os.path.dirname(path)
                for target in MDLINK.findall(text):
                    if target.startswith(("http://", "https://", "mailto:")):
                        continue
                    checked += 1
                    if not os.path.isfile(os.path.normpath(os.path.join(base, target))):
                        broken.append((rel, target, "link"))

        if broken:
            print(f"docs-links: {len(broken)} broken of {checked} checked\n", file=sys.stderr)
            for rel, target, kind in broken:
                print(f"  {rel}: {kind} -> {target}", file=sys.stderr)
            return 1

        print(f"docs-links: {checked} references, all resolve")
        return 0


    sys.exit(main())
  ''
