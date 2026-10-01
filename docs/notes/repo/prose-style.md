# prose-style: rule 17's bans, in the tree and in the message

`tools/prose-style.nix`, wired into the pre-commit hooks in two modes. Run it by hand with
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

## The long form of rule 17

Moved here VERBATIM from [rules.md](../../rules.md) on 30/09/2026, when rule 17 became a
card. Nothing was cut; the card links back here.

**EVERYTHING IN THIS REPO IS WRITTEN IN en-US**: code comments, module header blocks, docs, option `description`s, commit messages, and file/directory names. The reason is REACH, not style. This repo is public, it is the most detailed record of how I work, and it is meant to be read by people who do not speak Portuguese. THE MIGRATION IS INCREMENTAL, AND HALF-TRANSLATED IS THE WORST OF THE THREE STATES, so it needs a hard boundary instead of good intentions: **whatever you touch, you leave in en-US.** New files are born in en-US; an edited file gets translated IN THE SAME COMMIT that edits it, never in a "translation pass later" that never comes (that is rule 16's drift, applied to language). Rules 1-16 above, all of `docs/`, the `.nix` tree, the Hyprland Lua, the Quickshell QML, `scripts/`, the CI workflow and the tooling files were all translated and renamed on 15/08/2026, the day this rule was written, so THE MIGRATION IS DONE and this rule now only governs what comes next. What deliberately stays in pt-BR is a short, closed list, and each item says why where it lives: the LOCKSCREEN (a product decision, recorded in the july history), the names of Brazilian holidays plus the month and weekday names in the bar's calendar (official names of local events, the same class of literal as a city's name), and runtime identifiers whose rename would be a behavior change and not a translation (the `my.archAntigo` option, the `arch-antigo-mount` unit, `/mnt/arch-antigo`, the "Arch antigo" Dolphin bookmark, `/srv/media/media/Filmes`). RENAME WITH `git mv`, NEVER delete+create, because the history of a file IS the product here and delete+create severs it. THE RULE NUMBERING SURVIVES TRANSLATION: `docs/regras.md` became `docs/rules.md`, and the comments citing "regra N" became "rule N" **with the same N**. The numbering is API (see this file's header), so translating it renames the WORD, never the number. COMMITS: conventional commits (`feat|fix|docs|chore(scope): subject`), subject AND body in en-US, and **one commit per feature/task**, never one blob at the end of the day. That is rule 8 seen from the git side, and it matters for the same reason the header blocks matter: the history is the diary that explains WHY, and a blob erases it. **NEVER a `Co-Authored-By:` trailer**, for Claude or any other tool: who typed is not who decided, and the authorship of this repo is not shared. **NO EM DASHES** (`—`) in prose, anywhere. A comma, a colon or a new sentence always reads better, and leaning on the em dash is a tic that flattens every paragraph into the same shape. The exception is the em dash as a LITERAL and not as prose: the "—" glyph used on screen to mean "no value", and a regex matching somebody else's window title that contains one. **NO EMOJI**, on the same terms and for a stricter reason: not in docs, not in comments, not in commit messages, not in an option `description`. A marker like the warning sign is not emphasis, it is a claim that THIS paragraph matters more than the one next to it, and when every trap carries one the marker stops meaning anything. What already earned emphasis has CAPS and bold, which survive `grep`, a diff and a terminal with no font for pictographs. The exception is anything that is a literal being quoted and not decoration: a program's own output (`sbctl status` prints a check mark) or a codepoint the text is discussing (`U+2764`). Same exception as the em dash, for the same reason. **FIRST PERSON, NOT MY OWN NAME**: this repo is mine, so it says "my dotfiles", never "v1cferr's dotfiles" or the impersonal "the user's dotfiles", which read like a third party documenting my machine. Second person is reserved for the READER ("the ones you need to read this tree"), which keeps the two voices from colliding. The exception is anything that is a literal identifier and not a figure of speech: `ssh.v1cferr.dev`, the `v1cferr` user account, paths under `/home/v1cferr`.

## The long form of rule 2

Moved here VERBATIM from [rules.md](../../rules.md) on 30/09/2026, when rule 2 became a
card. Nothing was cut; the card links back here.

COMMENTS ARE SHORT, in EVERY file and with no exception. **AT MOST 2 LINES, ANYWHERE**: that is the cap for the module header AND for every comment inside it, per config, per package, per list item. The header says what the module is and where the detail lives. The detail itself goes to [`notes/`](../), never into the file. A comment records the why and the trap in one line, never the thing the code already says. THE REASON THIS RULE CHANGED TWICE: it first forbade the header block, then allowed it because the repo had them anyway, and the blocks grew until 36% of the tree was comment and one module carried a 123-line header (measured on 16/08/2026, 6062 comment lines in 16634). A header that long is not documentation, it is a wall you scroll past to reach the code, and the reasoning inside it was invisible to anyone reading `docs/`. So the reasoning MOVED instead of being deleted: `notes/<module>.md` holds the why, the measurements and what was tried and rejected, and the 2-line header points at it. The sweep landed on 16/08/2026: 1601 comment lines in 13299, 12%, with NOTHING deleted, only relocated. Whatever you touch, you shorten.
