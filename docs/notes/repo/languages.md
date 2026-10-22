# Languages: four for glue, Python for programs

The long form of [rule 24](../../rules.md#24-four-languages-for-glue-python-for-programs).

## The policy (21/10/2026, revised 22/10/2026)

Configuration and glue are written in, by priority:

| Language | Why it is here |
| --- | --- |
| Nix | the repo IS a flake: every module, package, check and host |
| Lua | Hyprland's configuration language (`modules/home/desktop/hypr/lua/`) |
| QML | Quickshell's: the bar, the glance band, the OSD, the lock screen |
| Shell | glue, preferably inside a `.nix` (`writeShellApplication`), else a `.sh` beside its module (rule 7) |

**A PROGRAM may be Python.** A program is code with its own data structures, arithmetic past
counting, a test suite, or about 100 lines of logic. A `jq` or `awk` script that grew past a filter
is a program too, and belongs here rather than in a shell string. Each one is registered below
with a reason and a review date (rule 22).

**An exception for any other language exists only where a HOST imposes it**, the same reason Lua
and QML are here: a program that only accepts extensions written in X. It lives inside its
feature's folder and is registered the same way. Third-party code the repo only PACKAGES (an
upstream Python app built with `buildPythonApplication`) is not code the repo writes, and is not
counted.

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

| Path | Language | Reason | Review |
| --- | --- | --- | --- |
| `modules/home/shell/kitty/smart-paste.py` | Python | host: kitty runs kittens in its own Python | 21/10/2027 |
| `modules/home/network/fai-workstation.nix` (the WoL relay, 6 lines) | Python | host: it runs ON the fai-vm, whose only unprivileged broadcaster is `python3`; that host is not mine to change | 22/10/2027 |
| `modules/home/desktop/vicinae/repositories/` | TypeScript | host: Vicinae's API is React in TypeScript | 21/10/2027 |
| `tools/docs-site/` | TypeScript | the docs site (Next.js and Fumadocs), kept by choice on 21/10/2026 and again on 22/10/2026 | 21/10/2027 |
| `modules/home/desktop/calendar/scripts/registry.py` and its test | Python | program: date arithmetic, the computus, a test suite | 22/10/2027 |
| `tools/repo-stats/render.py` | Python | program: it draws the README's SVGs | 22/10/2027 |
| `tools/eval-metrics/` | Python | program: evaluator stats, budgets, formatted tables | 22/10/2027 |
| `tools/usage-audit/`, `tools/exposure-check/` | Python | programs: each about 110 lines of logic | 22/10/2027 |
| `pkgs/razer-dpi/` | Python | program: ioctls on hidraw | 22/10/2027 |
| `modules/home/desktop/vicinae/scripts.nix` (the icon heredoc) | Python | it draws a glyph through fontTools' pens, an API with no command-line form | 22/10/2027 |

**Known debt, by the revised rule:** `tools/router-ssot/` and `tools/dead-config/` are `jq`
programs ported before the revision. They are measured and correct, so they stay; the day either
needs a real change, it goes back to Python first.

## What was migrated, and stays shell

Each one MEASURED against the Python it replaced; the detail is in each tool's note.

| Date | What | Now |
| --- | --- | --- |
| 21/10/2026 | the lock screen's `render.py`, `observe.py` and four test files | QML ([lockscreen](../desktop/lockscreen.md)) |
| 22/10/2026 | `data-syntax`, `rules-index`, `docs-links`, `prose-style` | shell: `rg`, `sed`, `jq` as a filter, `biome`/`taplo` as parsers |
| 22/10/2026 | `dead-config`, `router-ssot` | shell with a `jq` program (the debt above) |
| 22/10/2026 | Sunshine's `moonlight-stats`, the local WoL paths, `router-sync`, Zen's lab client | shell, `jq`, `socat`, `/dev/tcp` |

MEASURED on 22/10/2026: 930 lines left in `.py` files (1,183 before `router-sync.py` and
`zen/lab.py` left), and about 520 in `writePython3` bodies, down from about 1,578.

## What only Python needs

The `ruff` hook stays, since loose `.py` files remain. `python3` and `uv` in
`modules/nixos/packages.nix` are my own tools for other projects, not this repo's code, and are
not governed by this rule.
