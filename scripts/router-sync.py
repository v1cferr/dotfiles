"""router-sync: it mirrors the OpenWrt router's UCI into the repo, with the secrets redacted.

WHY IT EXISTS: the router's config was BLIND, 750 lines that existed only on the device,
invisible to the repo and to any review. This does not make the router declarative (Nix does not
reach over there); it makes the config VERSIONED and the drift VISIBLE, which is what was really
missing.

TWO ACTIONS, both safe:
  pull  brings the device's state into the repo (bootstrapping, and after touching LuCI)
  diff  compares device against repo and exits 1 if they diverge (it serves as a gate)

IT DOES NOT WRITE TO THE ROUTER. Pushing config is a separate decision, with a risk of its own
(one wrong network line locks you out) and it requires commit-confirm; see the TODO item in
docs/open-items.md.

SECRET REDACTION IS FAIL-SAFE, and the direction matters: it redacts BY DEFAULT everything whose
name suggests a credential, and it only releases what it recognizes as public. A new secret that
shows up in a future package is born redacted with nobody having to remember, whereas the
opposite (a block list) would leak in silence. Rule 12: the repo does not hold a credential, not
even by accident.
"""

import subprocess
import sys
from pathlib import Path

HOST = "v1cferr@192.168.1.1"
MARKER = "<REDACTED: the real value is on the router; see docs/history/>"

# The name of the option (the leaf) that carries a credential. The generic `key` is in there
# because that is the name wireless uses for the WiFi password.
SUSPECT = {
    "private_key",
    "preshared_key",
    "password",
    "passwd",
    "psk",
    "secret",
    "token",
    "key",
}

# Exceptions checked ONE by ONE, with the reason, since without that the list would become faith:
#   public_key  -> it is public by definition (the WireGuard peers)
# The other common case, `uhttpd.main.key` and `luci.flash_keep.passwd`, needs NO exception by
# name: both hold a file PATH, and a path is not a secret. Hence the "starts with /" test below,
# which generalizes to future options.
PUBLIC = {"public_key"}


def repo_root():
    """The SAME idiom as scripts/sync-secrets.sh. `__file__` is NO good: the script is copied
    into /nix/store, so a path relative to it points inside the store (which is read-only)
    instead of the repo. It already bit on the first run."""
    r = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True
    )
    if r.returncode != 0:
        print("run it from inside the repo (git rev-parse failed).", file=sys.stderr)
        sys.exit(2)
    return Path(r.stdout.strip())


def uci_configs():
    """The file names in /etc/config, without the backups we created ourselves."""
    out = ssh("ls /etc/config/")
    return sorted(c for c in out.split() if c and ".bak" not in c and "-bak" not in c)


def ssh(cmd):
    r = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", HOST, cmd],
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        print(f"ssh failed: {r.stderr.strip()}", file=sys.stderr)
        sys.exit(2)
    return r.stdout


def redact(line):
    """`config.section.option='value'` -> it redacts the value when the option smells like a
    secret."""
    if "=" not in line:
        return line
    option, value = line.split("=", 1)
    leaf = option.rsplit(".", 1)[-1]
    if leaf in PUBLIC or leaf not in SUSPECT:
        return line
    # A file path is not a secret, it is a pointer. It covers uhttpd.main.key and the like.
    if value.strip("'\"").startswith("/"):
        return line
    return f"{option}='{MARKER}'"


def export():
    """{config name: redacted text}. `uci show` and not `uci export`: the output is one line per
    option, so git's diff points at the LINE that changed instead of the whole block."""
    out = {}
    for cfg in uci_configs():
        raw = ssh(f"sudo uci show {cfg} 2>/dev/null || true")
        lines = [redact(x) for x in raw.splitlines() if x.strip()]
        if lines:
            out[cfg] = "\n".join(lines) + "\n"
    return out


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "diff"
    root = repo_root() / "router" / "uci"
    live = export()

    if action == "pull":
        root.mkdir(parents=True, exist_ok=True)
        for old in root.glob("*.conf"):
            if old.stem not in live:
                old.unlink()
                print(f"  removed  {old.name} (it no longer exists on the router)")
        for cfg, text in sorted(live.items()):
            target = root / f"{cfg}.conf"
            before = target.read_text() if target.exists() else None
            if before != text:
                target.write_text(text)
                print(f"  {'updated' if before else 'new':<10} {cfg}.conf")
        print(f"\n{len(live)} configs in {root}")
        return 0

    if action == "diff":
        diverged = False
        for cfg, text in sorted(live.items()):
            target = root / f"{cfg}.conf"
            if not target.exists():
                print(f"  ROUTER ONLY  {cfg}")
                diverged = True
            elif target.read_text() != text:
                print(f"  DIVERGES     {cfg}")
                diverged = True
        for old in sorted(root.glob("*.conf")) if root.exists() else []:
            if old.stem not in live:
                print(f"  REPO ONLY    {old.stem}")
                diverged = True
        if diverged:
            print("\nrun `router-sync pull` to bring the router's state over.")
            return 1
        print("the router and the repo are in sync.")
        return 0

    print(f"usage: router-sync [pull|diff]  (got: {action})", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
