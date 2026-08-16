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
| markdown outside `docs/history/` | a repo path quoted in prose, like `` `system/hardware/gpu.nix` `` |

### The prose-path check, and why history is exempt

A backticked path is the most common way these docs point at a module, and nothing was checking
it. Added 16/08/2026, it raised the count from 336 references to 531 and found three stale ones on
the first run. `docs/guides/bios-ex-b560m-v5.md` still pointed at a `gpu.nix` and a
`hardware.nix` directly under `system/`, from before the reorganisation into categories, and
`docs/ideas.md` referred to a `ddc.nix` that never survived: the DDC brightness curve was built
and REVERTED.

Note that this paragraph cannot QUOTE those paths, because the check would flag its own example.
That is the check working, not a limitation: a dead path in a doc that describes the present is
exactly what it exists to catch, and prose about a dead path reads better without the backticks
anyway.

`docs/history/` is exempt on purpose. It is a diary, it names files that were deleted deliberately,
and editing it to keep paths alive would stop it being evidence. That is the same reason
[`README.md`](../README.md) gives for history being append-only while notes are kept current.

A path belonging to SOMEBODY ELSE'S repo is written `Repo:path/to/file`, and the regex refuses to
match after a colon. Two Foundry paths in the impermanence item looked exactly like local ones
(`hosts/common/…`) and would have been permanent false positives otherwise, so they got the prefix
and now say what they are.

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
