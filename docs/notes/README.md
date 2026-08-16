# notes

One page per module, holding what used to live in its header block: **why the module is the
way it is**, the measurements behind each number, and what was tried and rejected.

## Why this folder exists

Rule 2 used to allow a header block "as long as it needs to be". Measured on 16/08/2026, that
had grown into **6062 comment lines out of 16634** across the tree, 36%, with one module
(`home/shell/claude-code.nix`) carrying a **123-line header**. A header that long stops being
documentation and becomes a wall you scroll past to reach the code. Worse, none of that
reasoning was reachable from `docs/`: to find out why Caddy has a jail, you had to already know
to open `system/services/caddy.nix`.

So the reasoning moved here instead of being deleted. The module keeps a 2-line header that says
what it is and points at its page.

## How it relates to the rest of docs/

| Folder | Question it answers |
| --- | --- |
| [`../history/`](../history/) | "What happened on that day, and what did I learn?" Chronological, append-only |
| `notes/` (here) | "Why is THIS module like this, right now?" One page per module, kept current |
| [`../guides/`](../guides/) | "What do I type to redo this by hand?" Steps outside Nix's reach |

The history is a diary and keeps its entries even when they go stale, because a diary that gets
edited stops being evidence. These notes are the opposite: they describe the CURRENT state, and
rule 16 applies in full, so a note that stops being true is a bug.

## Conventions

- **A page is created only when there is something to say.** A module whose header compresses to
  2 lines with nothing lost does not get a page.
- **The file name mirrors the module**, so `system/services/caddy.nix` becomes `caddy.md`.
- **The module points here, never the other way around.** The pointer lives in the 2-line header.
