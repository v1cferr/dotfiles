# The link checker

Its sibling is [`dead-config.md`](dead-config.md): this one asks "does every pointer
RESOLVE?", that one asks "is anything DECLARED and never used?". Two questions, two tools,
one `checks.repo-audit` running both.

`pkgs/docs-links.nix`, wired into `checks` so it runs on `nix flake check` and therefore in the CI
too. Run it by hand with `nix run .#docs-links`.

## Why it exists

Every module carries a 2-line header ending in a pointer at one of these pages, and the pages
cross-link each other. As of 16/08/2026 that is **274 references**: 128 pointers from code across
92 files, plus the links inside `docs/`.

Nothing verified any of them. Rule 16 says a note that stops being true is a bug, and rule 2 made
the pointer the ONLY path from a module to its reasoning, so a broken pointer silently undoes both:
the module still looks documented, and the documentation is unreachable.

**It caught a real one on its first run**: `docs/rules.md` still pointed at `docs/regras.md`, a
leftover the en-US migration of 15/08/2026 missed. It also made the folder reorganisation safe,
which is what it was written for: moving 51 pages rewrote 128 pointers and 113 links, and the only
way to know that landed was to check all 274 afterwards.

## What it checks, and what it deliberately does not

| Where | What counts |
| --- | --- |
| code (`.nix`, `.lua`, `.qml`, `.sh`, `.toml`, `.yaml`, `.yml`) | a bare `docs/…md` path, which is the form the headers use |
| markdown | only a real `](target)` link, resolved against the file's own directory |

**A bare path inside markdown is PROSE, not a pointer**, and that distinction is not pedantry: the
first version checked those too and flagged `docs/rules.md` for the sentence saying that the old
pt-BR filename "became" the current one. That sentence is history and it is correct. A file that
names its own past cannot be a broken link.

Out of scope on purpose: `http(s)` targets (that is a network check, not a repo check), `#anchors`
(a heading rename is a different class of drift, and matching them would mean parsing markdown
rather than scanning it), and a placeholder like `docs/notes/<module>.md`, which documents the
CONVENTION and names no file.

## Why `writePython3Bin`

The same reasoning as `writeShellApplication` in rule 7: the logic lives in the BUILD, and the
build is what lints it. `writeShellApplication` gives shellcheck; `writePython3Bin` gives flake8,
and it refused to build until the spacing was right, which is exactly the point of putting it
there.

`flakeIgnore = [ "E501" ]` because this repo's line length is 100 and flake8 defaults to 79. That
is the only rule relaxed.

## The one thing to know before editing it

It walks `git ls-files`, so an untracked file is invisible to it. That is deliberate (the check
should see what the repo ships, not what is lying around in the working tree), but it means a note
you created and did not `git add` will read as a broken pointer, and the fix is `git add`, not the
checker.
