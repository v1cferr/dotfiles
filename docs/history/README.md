# History

What was done and, more importantly, **why**, what was tried and **rejected**, and which
trap cost dearly. It is the file that answers "why is this like this?" six months later.

One folder per year, one file per month. A new entry goes into the current month, at the
top (reverse chronological order inside each file).

## 2026

| Month | Entries |
| --- | --- |
| [august](2026/08-august.md) | 75 |
| [july](2026/07-july.md) | 63 |

## How the dates were assigned

The split by month happened on 08/08/2026, when the history already had 98 entries and
only 35 carried an explicit date. The others were dated by cascade:

1. `dd/mm/yyyy` in the text, the date the author stated
2. `dd/mm` with no year, or `month/yyyy`, since the repo only has 2026
3. **Git archaeology**: `git log -S "<title>" --reverse` finds the commit that introduced
   the entry
4. No signal at all, so july, the month the repo opened

**9 july entries are there by inference from step 4.** They have no date in the text and
`git log -S` did not find the commit, most likely because they were rewritten after being
created, so the current string never existed in an old commit. July is a conservative
guess, not a fact.

One trap that got in the way of the archaeology and is worth recording: `git log`
restricted to `docs/` showed everything being born on 04/08, because that is when the file
moved into that folder. The real history starts on **18/07** and only shows up with
`--follow`, or by searching with `-S` without restricting the path.

## Convention for a new entry

A new entry **must** carry the date in its title, `(08/08/2026)`. That stops being style
and becomes what guarantees it lands in the right file with no archaeology.

FILE NAME: `MM-month.md`. The number in front is what sorts correctly; the name is what
gives meaning to the editor tab and to the file out of context. Do not repeat "history" or
the year, since the path already says both, and `MM-YYYY` would sort wrong the day two
years sat side by side (`01-2027` before `07-2026`).

A new year means a new folder (`2027/`) plus a first line in the table above. A new month
inside the current year means a new file (`09-september.md`) plus one line. These are
manual steps on purpose: automating them would cost more than the two lines a month.
