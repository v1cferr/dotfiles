# Languages: four for glue, Python for programs

The long form of [rule 24](../../rules.md#24-four-languages-for-glue-python-for-programs).

## The policy (21/10/2026, revised 22/10/2026)

Configuration and glue are written in, by priority:

| Language | Why it is here                                                                                      |
| -------- | --------------------------------------------------------------------------------------------------- |
| Nix      | the repo IS a flake: every module, package, check and host                                          |
| Lua      | Hyprland's configuration language (`modules/home/desktop/hypr/lua/`)                                |
| QML      | Quickshell's: the bar, the glance band, the OSD, the lock screen                                    |
| Shell    | glue, preferably inside a `.nix` (`writeShellApplication`), else a `.sh` beside its module (rule 7) |

Python is the ONE language allowed past these four, and only for a PROGRAM. Third-party code the
repo only PACKAGES (an upstream Python app built with `buildPythonApplication`) is not code the
repo writes, and is not counted.

## How to choose

Walk the steps in order and stop at the FIRST one that fits. The order is the point: each step is
cheaper to keep than the next.

**0. No code.** Look for a NixOS or home-manager option, or a tool already in nixpkgs, before
writing anything (rules 1 and 3). The best script is the one that does not exist.

**1. Nix**, when the job is data, validation or generation that can happen at evaluation or build:
a list of ports, a config file rendered from options, an assertion.

**2. The host's language**, when a program only accepts extensions in one language: Lua for
Hyprland, QML for Quickshell, Python for a kitty kitten, TypeScript for a Vicinae extension.

**3. Shell**, when the job is GLUE: each line runs another program and passes its output on, and
the control flow is sequence, a `case` on a subcommand, an exit code checked, a retry. `jq`,
`sed`, `awk` and `rg` belong here only as ONE-LINE filters (`jq -r '.name'`, `rg -c pattern`).
Examples: `moonlight-stats` (journalctl into one `jq` filter), `data-syntax` (three parsers
called per file), the local WoL paths (`socat`).

**4. Python**, when ANY of these signals shows. One is enough:

| Signal | What it looks like | Why shell loses |
| --- | --- | --- |
| Structured state | maps of lists, sets, a graph, a state machine | bash has one flat associative array |
| Math past counting integers | dates and time zones, IPs and masks, floats, statistics, number formatting | integer-only, and every formatting rule is hand-written |
| A format no one-line command reads | binary data, ioctls, a library API | there is no tool to call |
| Edge cases worth a unit test | a parser, a calculation with boundaries | no test runner, so the cases go unpinned |
| A filter that grew | `jq` or `awk` with `def`, `reduce`, or more than about 5 lines | it is a fifth language hidden in a string |
| Size | more than **100 lines of logic**, comments and blank lines excluded | see below |

Examples: the calendar registry (dates and the computus, with tests), `razer-dpi` (ioctls),
Vicinae's icons (fontTools' pen API), `eval-metrics` (number formatting and budgets).

**The 100-line limit is a smell before it is a verdict.** A basic job that needs more than 100
lines of logic, in ANY language, usually means a missing tool (back to step 0) or a design doing
too much (split it, or cut it). Only when neither holds is it a program, and then it is Python. A
Python file past about 200 lines of logic splits into modules (`eval-metrics` warns past its
budget).

**5. Never.** A program written in `jq`, `awk`, `sed` or Perl; TypeScript for the repo's own
tooling; a sixth language for any reason. `router-ssot` is the example of what this step forbids:
a `jq` program of 139 lines with functions and IP arithmetic.

**Everything outside the four is registered** in the table below with its reason and a review
date (rule 22): each Python file, and each host-imposed language.

## Why the policy was revised (22/10/2026)

The first version allowed four languages and nothing else, and its plan moved every Python
program to shell. Phase A (the six pre-commit checkers) and part of phase C went that way, one
commit each, each MEASURED against the Python it replaced. Two measurements changed the plan:

- **Speed was not the gain.** Every checker runs under half a second either way; `docs-links`
  went from 0.07s to 0.14s, since bash spawning `rg` costs more than a Python already running.
- **The cost was silent bugs.** Six showed up only because each port was diffed against the
  Python, and none of them can exist in Python: a `jq` `A + B as $x` binding that dropped 8 of 11
  findings, a `.` rebound inside a `jq` pipe, an `exit` inside `$(...)` that would have turned a
  failed ssh into "in sync", an `ssh` that swallowed its loop's input, a thousands separator
  grouped from the left (`28,328` printed as `283`), and a NUL byte bash cannot hold.

And the language count it bought was partly an illusion: `router-ssot` and `dead-config` became
`jq` programs of 50 to 130 lines with functions and IP arithmetic, so one language was traded for
four dialects (bash, `jq`, PCRE, `sed`). Glue in shell is shorter and clearer than Python; a
program in shell is neither.

## The registered exceptions

| Path                                                                | Language   | Reason                                                                                                         | Review     |
| ------------------------------------------------------------------- | ---------- | -------------------------------------------------------------------------------------------------------------- | ---------- |
| `modules/home/shell/kitty/smart-paste.py`                           | Python     | host: kitty runs kittens in its own Python                                                                     | 21/10/2027 |
| `modules/home/network/fai-workstation.nix` (the WoL relay, 6 lines) | Python     | host: it runs ON the fai-vm, whose only unprivileged broadcaster is `python3`; that host is not mine to change | 22/10/2027 |
| `modules/home/desktop/vicinae/repositories/`                        | TypeScript | host: Vicinae's API is React in TypeScript                                                                     | 21/10/2027 |
| `tools/docs-site/`                                                  | TypeScript | the docs site (Next.js and Fumadocs), kept by choice on 21/10/2026 and again on 22/10/2026                     | 21/10/2027 |
| `modules/home/desktop/calendar/scripts/registry.py` and its test    | Python     | program: date arithmetic, the computus, a test suite                                                           | 22/10/2027 |
| `tools/repo-stats/render.py`                                        | Python     | program: it draws the README's SVGs                                                                            | 22/10/2027 |
| `tools/eval-metrics/`                                               | Python     | program: evaluator stats, budgets, formatted tables                                                            | 22/10/2027 |
| `tools/usage-audit/`, `tools/exposure-check/`                       | Python     | programs: each about 110 lines of logic                                                                        | 22/10/2027 |
| `pkgs/razer-dpi/`                                                   | Python     | program: ioctls on hidraw                                                                                      | 22/10/2027 |
| `modules/home/desktop/vicinae/scripts.nix` (the icon heredoc)       | Python     | it draws a glyph through fontTools' pens, an API with no command-line form                                     | 22/10/2027 |

## Known debt, by the steps above

MEASURED on 22/10/2026 in lines of logic (comments and blank lines excluded). Each one is past the
limit or a `jq` program, so by step 4 or 5 it is a program in the wrong language. A debt is paid
the day its file is touched for a real change, the way rule 17 handles en-US, never in a separate
sweep:

| Script | Logic | Reading |
| --- | ---: | --- |
| `modules/home/desktop/glance-feed/scripts/feed.sh` | 630 | a program: HTTP, state in SQLite, JSON |
| `vpn` in `modules/nixos/network/vpn.nix` | 201 | long glue, a CLI with subcommands: simplify, else Python |
| `bios-aspm` in `hosts/ex-b560m-v5/bios-aspm.nix` | 193 | it edits bytes of an EFI variable: a program |
| `tools/router-ssot/` | 139 | a `jq` program (step 5) |
| `tools/dead-config/` | 122 | a `jq` program (step 5) |
| `modules/nixos/core/sync-secrets.sh` | 103 | borderline: simplify first |
| `router-sync` in `modules/nixos/network/router.nix` | 102 | borderline: ported from Python on 22/10/2026, and back to it if it grows |
| `mega-dl` in `modules/home/network/mega.nix` | 102 | borderline: simplify first |

## What was migrated, and stays shell

Each one MEASURED against the Python it replaced; the detail is in each tool's note.

| Date       | What                                                                               | Now                                                              |
| ---------- | ---------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| 21/10/2026 | the lock screen's `render.py`, `observe.py` and four test files                    | QML ([lockscreen](../desktop/lockscreen.md))                     |
| 22/10/2026 | `data-syntax`, `rules-index`, `docs-links`, `prose-style`                          | shell: `rg`, `sed`, `jq` as a filter, `biome`/`taplo` as parsers |
| 22/10/2026 | `dead-config`, `router-ssot`                                                       | shell with a `jq` program (the debt above)                       |
| 22/10/2026 | Sunshine's `moonlight-stats`, the local WoL paths, `router-sync`, Zen's lab client | shell, `jq`, `socat`, `/dev/tcp`                                 |

MEASURED on 22/10/2026: 930 lines left in `.py` files (1,183 before `router-sync.py` and
`zen/lab.py` left), and about 520 in `writePython3` bodies, down from about 1,578.

## What only Python needs

The `ruff` hook stays, since loose `.py` files remain. `python3` and `uv` in
`modules/nixos/packages.nix` are my own tools for other projects, not this repo's code, and are
not governed by this rule.
