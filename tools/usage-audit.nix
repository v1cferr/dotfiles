# usage-audit: every app in home.packages next to the traces of its use, so a quarterly review has
# a list to argue with. A report, never a gate: docs/notes/repo/usage-audit.md
{ writers }:

writers.writePython3Bin "usage-audit"
  {
    flakeIgnore = [ "E501" ]; # the repo's line length is 100, not flake8's 79
  }
  ''
    """List the user's apps by how recently anything shows they were used."""
    import datetime
    import json
    import os
    import re
    import sqlite3
    import subprocess
    import sys

    HOME = os.path.expanduser("~")
    ATUIN = f"{HOME}/.local/share/atuin/history.db"
    ZSH = f"{HOME}/.zsh_history"
    DRUN = f"{HOME}/.cache/rofi3.druncache"
    HOST = subprocess.run(["hostname"], capture_output=True, text=True).stdout.strip()
    USER = os.environ.get("USER", "v1cferr")

    # A keybind, a bar widget, an editor setting or a unit's `/bin/<name>` is a use no history sees.
    # A bare name in a .nix is NOT: the module that installs a package names it too.
    WIRED_EXT = (".lua", ".qml", ".json")


    # One eval for everything the CONFIG says about use: the apps, the aliases that rename them, the
    # programs.* a module wires into the shell, and the MIME defaults a double click opens.
    APPLY = """hm: {
      pkgs = map (p: { name = p.pname or p.name; out = p.outPath; }) hm.home.packages;
      aliases = hm.programs.zsh.shellAliases // hm.home.shellAliases;
      programs = builtins.filter (n: (builtins.tryEval (hm.programs.''${n}.enable or false)).value == true)
        (builtins.attrNames hm.programs);
      mime = builtins.concatLists (builtins.attrValues hm.xdg.mimeApps.defaultApplications);
    }"""


    def config(extra):
        attr = f".#nixosConfigurations.{HOST}.config.home-manager.users.{USER}"
        out = subprocess.run(["nix", "eval", "--json", attr, "--apply", APPLY, *extra],
                             check=True, text=True, capture_output=True).stdout
        return json.loads(out)


    def entries(out, sub, suffix):
        path = os.path.join(out, sub)
        return sorted(f.removesuffix(suffix) for f in os.listdir(path) if f.endswith(suffix)) if os.path.isdir(path) else []


    def shell_history():
        """First word of every command, with the newest timestamp seen; zsh fills in undated counts."""
        seen = {}
        if os.path.exists(ATUIN):
            db = sqlite3.connect(f"file:{ATUIN}?mode=ro", uri=True)
            for cmd, ts in db.execute("select command, max(timestamp) from history group by command"):
                for word in re.findall(r"(?:^|[|;&]\s*)(?:sudo\s+)?([\w.+-]+)", cmd):
                    seen[word] = max(seen.get(word, 0), ts // 10**9)
        if os.path.exists(ZSH):
            for line in open(ZSH, errors="replace"):
                m = re.match(r"(?:: (\d+):\d+;)?\s*(?:sudo\s+)?([\w.+-]+)", line)
                if m:
                    seen[m[2]] = max(seen.get(m[2], 0), int(m[1] or 0))
        return seen


    def launches():
        """rofi's drun cache: `<count> <file>.desktop` per line."""
        if not os.path.exists(DRUN):
            return {}
        return {name.removesuffix(".desktop"): int(n) for n, name in (ln.split(" ", 1) for ln in open(DRUN).read().split("\n") if " " in ln)}


    def wiring():
        """The name in a .lua/.qml/.json, or `/bin/<name>` or `getExe <name>` in a .nix."""
        files = subprocess.run(["git", "ls-files"], check=True, text=True, capture_output=True).stdout.split()
        read = {f: open(f, errors="replace").read() for f in files if f.endswith((*WIRED_EXT, ".nix")) and os.path.isfile(f)}
        loose = "\n".join(t for f, t in read.items() if f.endswith(WIRED_EXT))
        nix = "\n".join(t for f, t in read.items() if f.endswith(".nix"))

        def hit(b):
            named = re.search(rf"(?<![\w-]){re.escape(b)}(?![\w-])", loose)
            called = re.search(rf"(/bin/|getExe'? (pkgs\.)?){re.escape(b)}(?![\w-])", nix)
            return bool(named or called)
        return hit


    def main():
        extra = sys.argv[1:]  # e.g. the CI's --override-input for the private input
        history, drun, is_wired, cfg = shell_history(), launches(), wiring(), config(extra)
        # An alias typed is its target used: `ls` in the history is a use of eza.
        for alias, target in cfg["aliases"].items():
            if alias in history:
                word = target.split()[0]
                history[word] = max(history.get(word, 0), history[alias])
        mime = {m.removesuffix(".desktop") for m in cfg["mime"]}
        rows = []
        for pkg in cfg["pkgs"]:
            bins = entries(pkg["out"], "bin", "")
            apps = entries(pkg["out"], "share/applications", ".desktop")
            if not bins and not apps:
                continue  # a theme, a font or a data dir: nothing to launch, nothing to audit
            last = max((history.get(b, 0) for b in bins), default=0)
            typed = any(b in history for b in bins)
            opened = sum(drun.get(a, 0) for a in apps)
            by = [why for why, hit in (
                ("config", any(is_wired(b) for b in bins)),
                ("module", pkg["name"] in cfg["programs"] or any(b in cfg["programs"] for b in bins)),
                ("mime", any(a in mime for a in apps)),
            ) if hit]
            rows.append((pkg["name"], last, typed, opened, ", ".join(by)))

        # No trace at all first, then the oldest dated use: the top of the list is the question.
        rows.sort(key=lambda r: (bool(r[2] or r[3] or r[4]), r[1]))
        print("| App | Last typed | Launched (rofi) | Wired by |")
        print("| --- | --- | ---: | --- |")
        for name, last, typed, opened, by in rows:
            when = datetime.date.fromtimestamp(last).isoformat() if last else ("undated" if typed else "")
            shown = str(opened) if opened else ""
            print(f"| {name} | {when} | {shown} | {by} |")
        quiet = [r[0] for r in rows if not (r[2] or r[3] or r[4])]
        print(f"\n{len(rows)} apps, {len(quiet)} with no trace: {', '.join(quiet) or 'none'}")


    main()
  ''
