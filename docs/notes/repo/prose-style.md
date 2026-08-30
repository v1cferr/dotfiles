# prose-style: rule 17's bans, in the tree and in the message

`pkgs/prose-style.nix`, wired into the pre-commit hooks in two modes. Run it by hand with
`nix run .#prose-style`, and over a message with
`nix run .#prose-style -- --commit-msg .git/COMMIT_EDITMSG`.

Rule 17 bans three things mechanically: the em dash in prose, the emoji anywhere, and the
`Co-Authored-By` trailer. Until this existed, all three were me remembering, and the history proves
memory is not a standard: **3 commits carry a `Co-Authored-By` trailer**, written before the rule
was. History is append-only, so those stay; what this stops is the fourth.

## The three checks

| Check | Where it looks | Why it is silent otherwise |
| --- | --- | --- |
| em dash | markdown prose and code COMMENTS | nothing breaks, the paragraph just flattens into the same shape as every other one |
| emoji | the same two places, plus the commit message | a warning sign is a claim that THIS paragraph matters more, and when every trap has one the marker means nothing |
| `Co-Authored-By` | the commit message only | git accepts it, GitHub renders it, and the authorship of this repo is not shared |

The grammar of the message itself (`feat|fix|docs(scope): subject`) is NOT here: that is `convco`,
a hook that already exists (see [`flake.md`](flake.md)).

## What counts as PROSE, and why the naive version is wrong

The naive check is `grep` for the glyph, and it fails immediately: this repo has **18 em dashes in
tracked files and every one of them is legitimate**, because rule 17's own exception is the em dash
as a LITERAL. The measurement that shaped every rule below is that list.

- **A code span is not prose.** `docs/notes/desktop/weather.md` writes the bar's no-value output as
  a span three times, and the august history discusses `U+2764` by quoting the glyph itself. Fenced
  blocks go out for the same reason, and the case that motivated it was a runbook quoting `sbctl
  status` printing a check mark: a program's own output is a literal, not decoration.
- **A quoted GLYPH is not prose, a quoted PHRASE is.** `docs/rules.md` names the exception by
  writing the glyph in double quotes. So a quoted run of at most 3 characters is dropped, and
  anything longer stays checked: the point is to exempt a symbol, never a sentence.
- **A table cell whose whole content is the em dash is a value, not punctuation.**
  `docs/notes/desktop/bar.md` has two, meaning "not measured". A prose em dash between clauses
  survives this, because the cell rule needs the pipes on both sides.
- **In code, only the COMMENT is prose.** The 27 `.qml` files are full of `"—"` as the label a
  binding falls back to, and `Bar.qml` matches a window title containing one with a regex. Neither
  is prose, so the string literals are stripped before the comment marker is looked for. That order
  matters twice: it is also what keeps a hex color (`"#7aa2f7"`, and the palette is full of them)
  from being read as the start of a `#` comment.
- **The emoji class is narrow on purpose.** The pictographic planes, the three status markers and
  VS16, which is what an emoji picker appends. The BMP symbols this repo uses as literals are
  deliberately NOT in it: the check mark above, the bare `U+2764` in the history, and the arrows,
  bullets and box drawing that make up the diagrams in `docs/`. A lint that flags a box-drawing
  character is a lint you learn to skip, which is the same argument [`flake.md`](flake.md) makes
  for the two statix rules that are off.

MEASURED after all of it: 236 files of prose, 0 findings. Like four of the `dead-config` checks,
this is a REGRESSION GUARD and not a bug finder, and that is the honest description of it.

## The script carries no glyph it forbids

Every codepoint in it is an escape (`\u2014`, `\uFE0F`), so the file is pure ASCII. A checker
holding the character it bans is a checker that flags itself the day the stripping rules change,
and debugging that costs more than the escapes cost to read.

## What it does NOT cover

- **The CI cannot run the message mode.** `nix flake check` runs `pre-commit run --all-files`,
  which only runs `pre-commit`-stage hooks, and there is no message inside that sandbox. Same limit
  `convco` has, recorded for the same reason.
- **QML block comments** (`/* ... */`) are not scanned; the tree uses `//` everywhere today.
- **A glyph in single quotes inside a comment** is flagged, because only double quotes are treated
  as a literal. Apostrophes are everywhere in this repo's prose, and eating the rest of the line
  after one would silently stop checking it. Flagging beats going quiet.
- **en-US itself.** The half of rule 17 that matters most is not mechanical: no check here can tell
  Portuguese prose from English. That one stays with the reader.

## The ALLOWED list

Empty, and keyed by `(path, line)` with a REASON string, so an exception lands in the diff instead
of rotting in silence. Same contract as `dead-config`: if a finding is real, the fix is rewriting
the sentence, not adding a line here.
