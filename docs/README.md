# docs

It used to be a single file (`ANOTACOES.md`, 1949 lines). It became six, because a god
file hides things: with 98 closed entries mixed in with 15 open ones, finding what to do
today meant scrolling through six months of history.

The split is by **function**, not by topic. What you read every day (the rules), what you
act on (the open items) and what you look up (the history) have different rhythms.

| File | What it is | When you read it |
| --- | --- | --- |
| [rules.md](rules.md) | The repo's 18 rules | Before deciding anything |
| [open-items.md](open-items.md) | What is still open | When picking what to work on |
| [history/](history/) | What was done and why, a folder per year and a file per month | "Why is this like this?" |
| [ideas.md](ideas.md) | Considered, not decided yet | When planning |
| [arch-legacy.md](arch-legacy.md) | A closed chapter + how to open the archive | Rarely |
| [guides/](guides/) | Step by step for what Nix cannot reach (BIOS, Secure Boot, router, Windows) | When reinstalling or working outside the repo |
| [tests/](tests/) | Reusable test protocols | When validating a change |

## Conventions

**The rule numbering is API.** The code cites "rule 11" and "rule 14" in more than seventy
comments. Renumbering would break all of them silently: a new rule goes in at the end, a
dead rule gets struck through instead of disappearing.

**A good entry explains the WHY and the trap**, not the what, because the code already says
the what. The most valuable entries here are the ones recording something TRIED AND
REJECTED, because they keep the next person (or you in six months) from repeating it.

**A finished item migrates** from `open-items.md` to `history/<month>.md`. One file only
grows, the other one shrinks.
