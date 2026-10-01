# Contributing

This is the configuration of my own machine, so the bar for a change is "is it true for this
machine", not "is it a good idea in general". That still leaves room: a bug, a stale doc, a better
idiom, or a security problem are all welcome.

## How

1. **Open an issue first**, at <https://github.com/v1cferr/dotfiles/issues>. It is where a change
   gets discussed before anyone writes it, and a bug report needs nothing more.
2. **A security problem never goes in an issue**: follow [SECURITY.md](SECURITY.md).
3. **A pull request** is welcome once the issue agrees on the change. I review every one myself,
   and merge, change or decline it with a reason.

## What a change needs

- **The gate passes**: `nix flake check --option abort-on-warn true`. The devShell (`nix develop`,
  or `direnv allow`) installs the same checks as git hooks, so they run before each commit.
- **It follows [the rules](../docs/rules.md)**: en-US everywhere, conventional commits (`feat|fix|
  docs|chore(scope): subject`), one commit per task, and never a `Co-Authored-By:` trailer.
- **The reasoning goes to `docs/notes/`**, and the comment in the code stays at most two lines,
  pointing at it.

## Tests

New functionality comes with the check that proves it. A new checker ships with a SENTINEL: a
planted case it must fail on, run once and recorded in its note with the date. A new module is
covered by the gate, which evaluates the host and builds every package, and by the boot test
(`nix run .#vm-boot`) when it runs at boot.
