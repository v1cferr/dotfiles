# dead-config: it fails when something is DECLARED and never used. Rule 16 says dead config leaves,
# and until this existed only memory enforced it. The 5 checks: docs/notes/repo/dead-config.md
{ writers }:

writers.writePython3Bin "dead-config"
  {
    libraries = [ ];
    flakeIgnore = [ "E501" ]; # the repo's line length is 100, not flake8's 79
  }
  ''
    """Fail when a module, an input, an option, a note or a secret is declared and never used."""
    import json
    import os
    import re
    import subprocess
    import sys

    ROOT = os.environ.get("DEAD_CONFIG_ROOT") or subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()

    # A tracked exception needs a REASON, so it shows up in the diff instead of rotting in silence.
    # Emptying this list is the goal, not growing it.
    ALLOWED = {}

    CODE_EXT = (".nix", ".lua", ".qml", ".sh", ".toml", ".yaml", ".yml")


    def tracked():
        out = subprocess.run(
            ["git", "-C", ROOT, "ls-files"],
            capture_output=True, text=True, check=True,
        ).stdout.split()
        return [f for f in out if os.path.isfile(os.path.join(ROOT, f))]


    def read(rel):
        try:
            return open(os.path.join(ROOT, rel), encoding="utf-8").read()
        except (UnicodeDecodeError, OSError):
            return ""


    def check_modules(files, _code):
        """A .nix under system/ or home/ that no `imports` reaches is a file nobody evaluates."""
        nix = {f: read(f) for f in files if f.endswith(".nix")}

        def imports_of(f):
            found = []
            base = os.path.dirname(f)
            for block in re.findall(r"imports\s*=\s*\[(.*?)\]", nix.get(f, ""), re.S):
                for m in re.finditer(r"\./([A-Za-z0-9_./-]+)", block):
                    p = os.path.normpath(os.path.join(base, m.group(1)))
                    for cand in (p + ".nix", os.path.join(p, "default.nix"), p):
                        if cand in nix:
                            found.append(cand)
                            break
            return found

        roots = ["system/default.nix", "home/default.nix"]
        roots += [f for f in nix if f.startswith("hosts/")]
        seen, stack = set(), list(roots)
        while stack:
            f = stack.pop()
            if f in seen:
                continue
            seen.add(f)
            stack.extend(imports_of(f))
        # pkgs/ is reached by callPackage in flake.nix, not by an `imports` list.
        return [("module", f, "no `imports` reaches it")
                for f in sorted(nix)
                if f not in seen and not f.startswith("pkgs/") and f != "flake.nix"]


    def check_inputs(_files, code):
        """A flake input nothing consumes still gets fetched, locked and evaluated."""
        flake = read("flake.nix")
        # The declaration block is where `<name>.url` lives, so a name that appears ONLY there is
        # never consumed. Everything after `outputs` is real use, including a bare destructured
        # argument (`nixpkgs-unstable`), which is why this cannot just grep for `inputs.<name>`.
        decl = flake[flake.index("inputs = {"):flake.index("outputs")]
        rest = code.replace(decl, "")
        lock = json.loads(read("flake.lock"))
        names = lock["nodes"][lock["root"]]["inputs"]
        return [("input", n, "declared in flake.nix, consumed nowhere")
                for n in sorted(names)
                if not re.search(r"\b" + re.escape(n) + r"\b", rest)]


    def check_options(_files, code):
        """A `my.*` option nobody reads is an SSOT with no consumer, which rule 11 exists to avoid."""
        dead = []
        for opt in sorted(set(re.findall(r"options\.my\.([A-Za-z0-9_.]+)\s*=", code))):
            esc = re.escape(opt)
            # A consumer may read the option itself or one of its children.
            if not re.search(r"(config|osConfig)\.my\." + esc + r"\b", code):
                dead.append(("option", "my." + opt, "declared, never read through config/osConfig"))
        return dead


    def check_notes(files, code):
        """A note no module points at is unreachable: rule 2 made the pointer the only path in."""
        def orphan(f):
            if not f.startswith("docs/notes/") or not f.endswith(".md"):
                return False
            return os.path.basename(f) != "README.md" and f not in code

        return [("note", f, "no pointer from any module") for f in sorted(files) if orphan(f)]


    def check_secrets(_files, code):
        """A sops secret nothing consumes is a credential kept, re-encrypted and rotated for nobody."""
        keys = re.findall(r"^([a-z0-9_]+):", read("secrets/secrets.yaml"), re.M)
        dead = []
        for k in sorted(set(keys)):
            if k == "sops":  # sops' own metadata block, not a secret
                continue
            pats = [r"/run/secrets/" + k + r"\b",
                    r"sops\.secrets\.?\W*" + k + r"\b",
                    r"sops\.placeholder\." + k + r"\b"]
            if not any(re.search(p, code) for p in pats):
                dead.append(("secret", k, "in secrets.yaml, consumed nowhere"))
        return dead


    def check_secret_index(_files, _code):
        """An index entry with no value in the vault breaks the BUILD, not the evaluation.

        `system/core/secrets.nix` turns every key of bitwarden-secrets.json into a
        `sops.secrets.<name>`, so the index is a DECLARATION and the yaml is the VALUE. Deleting
        from one side only gets you `sops-install-secrets: the key '<name>' cannot be found`, and
        it surfaces at `nixos-rebuild`, which is a much slower loop than a pre-commit hook.
        """
        index = json.loads(read("secrets/bitwarden-secrets.json"))
        vault = set(re.findall(r"^([a-z0-9_]+):", read("secrets/secrets.yaml"), re.M))
        return [("secret-index", k, "in bitwarden-secrets.json, no value in secrets.yaml")
                for k in sorted(index) if k not in vault]


    # Build output and editor droppings that should never be committed. A .gitignore only stops
    # what is not tracked YET: `scripts/__pycache__/router-sync.cpython-313.pyc` was committed
    # before the rule existed, so it stayed tracked and invisible to the ignore file.
    ARTIFACTS = re.compile(
        r"(^|/)(__pycache__|\.direnv|node_modules|result(-.*)?)(/|$)"
        r"|\.py[cod]$|\.(swp|swo|orig|rej|bak|tmp)$|(^|/)\.DS_Store$"
    )


    def check_artifacts(files, _code):
        """A tracked build artifact is dead by definition: it is regenerated, never read."""
        return [("artifact", f, "build output or editor dropping, should not be tracked")
                for f in sorted(files) if ARTIFACTS.search(f)]


    CHECKS = (check_modules, check_inputs, check_options, check_notes, check_secrets,
              check_secret_index, check_artifacts)


    def main():
        files = tracked()
        code = "\n".join(read(f) for f in files if f.endswith(CODE_EXT))

        findings, allowed = [], []
        for check in CHECKS:
            for kind, name, why in check(files, code):
                key = f"{kind}:{os.path.basename(name)}"
                (allowed if key in ALLOWED else findings).append((kind, name, why, key))

        for kind, name, _why, key in allowed:
            print(f"dead-config: allowed {kind} {name}: {ALLOWED[key]}")

        if findings:
            print(f"\ndead-config: {len(findings)} declared and never used\n", file=sys.stderr)
            for kind, name, why, _key in findings:
                print(f"  {kind}: {name} ({why})", file=sys.stderr)
            print("\nRemove it, or add it to ALLOWED with a reason.", file=sys.stderr)
            return 1

        print(f"dead-config: {len(CHECKS)} checks, nothing declared and unused")
        return 0


    sys.exit(main())
  ''
