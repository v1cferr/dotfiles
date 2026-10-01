# rules-index: every citation points at a live rule

`tools/rules-index/package.nix`, wired into the pre-commit hooks and the gate's `repo-audit`. Run it by
hand with `nix run .#rules-index`.

## Why it exists

The numbering of [`rules.md`](../../rules.md) is API: measured on 30/09/2026, the tree cites a rule
512 times outside the history, and 178 commit messages cite one too, which can never be edited
since the `history` ruleset forbids rewriting. A citation of a number that does not exist, or of a
rule that was retired, reads as authority and points at nothing, which is rule 16's drift in the
one place the repo explains itself. Before the rewrite of the rules into cards, nothing checked it.

## What it checks, and what it only reports

- **FAILS** on `rule N` (and `rules N and M`, `rules N, M or P`) anywhere in the tree when `N` is
  not a rule in `rules.md`, or is a RETIRED one (its line opens with `~~`).
- **SKIPS** `docs/history/`: a citation there is right about the day it was written, forever.
- **ALLOWS a retired number where the text is about the past**: a record in `docs/decisions/`,
  and a section titled "The long form of rule N" or "The former rule N", which holds a rule's
  text moved verbatim when it became a card. A number that never existed fails there too.
- **SKIPS** anything inside backticks, which is a quoted literal and not a citation: the same
  exception rule 17 makes for an em dash, and what lets this page show its own examples.
- **REPORTS** how many live rules name a check in their `**Enforced by**:` line and how many are
  held by review alone. That count is the coverage of the rules by machine, and it is a number to
  read, not to fail on: some rules are judgment and will stay that way.

## The two false positives the first run found

- **`rule 73`** in [razer](../hardware/razer.md) was udev's `73-seat-late.rules`, not a rule of
  this repo. The sentence now names the file, which also reads better.
- **`(rule 22, 29/09/2026)`** read as two citations, the second one of a rule numbered 29. A number followed by `/` is a date, so it
  ends the run instead of joining it.

MEASURED with a sentinel file citing, outside backticks, `rule 23 and rules 4, 99 or 2`: it
reported 23 and 99, and passed 4 and 2.
