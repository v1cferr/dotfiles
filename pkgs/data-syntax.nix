# data-syntax: it fails on a .json/.jsonc/.toml that does not PARSE. Most of them are read by a
# TOOL at runtime and by nothing at build time, so a broken one is silent: docs/notes/repo/flake.md
{
  writers,
  python3Packages,
}:

writers.writePython3Bin "data-syntax"
  {
    libraries = [ python3Packages.json5 ];
    flakeIgnore = [ "E501" ]; # the repo's line length is 100, not flake8's 79
  }
  ''
    """Fail on a .json/.jsonc/.toml this repo ships that does not parse."""
    import json
    import sys
    import tomllib

    import json5

    # VS Code DOCUMENTS comments in its own settings and keybindings, so these three are JSONC in
    # spite of the .json name. Every other .json here is read by a STRICT parser (Nix's fromJSON,
    # an MCP client, Claude Code), and there a comment is a broken file and not a note.
    JSONC = (
        ".vscode/settings.json",
        "home/apps/vscode/settings.json",
        "home/apps/vscode/keybindings.json",
    )


    def parse(path):
        """Parse one file in the dialect its CONSUMER accepts, never a laxer one."""
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        if path.endswith(".toml"):
            tomllib.loads(text)
        elif path.endswith(".jsonc") or path in JSONC:
            json5.loads(text)
        else:
            json.loads(text)


    def main():
        paths = sys.argv[1:]
        broken = []
        for path in paths:
            try:
                parse(path)
            except (ValueError, OSError) as err:
                broken.append(path)
                print(f"data-syntax: {path}: {err}", file=sys.stderr)

        if broken:
            print(
                f"data-syntax: {len(broken)} file(s) do not parse, so whatever reads them "
                "falls back to its defaults without saying so",
                file=sys.stderr,
            )
            return 1

        print(f"data-syntax: {len(paths)} file(s) parse")
        return 0


    sys.exit(main())
  ''
