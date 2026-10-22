# Languages: four, and an exception only where a host imposes one

The long form of [rule 24](../../rules.md#24-four-languages-an-exception-only-by-host).

## The policy (21/10/2026)

The repo is written in, by priority:

| Language | Why it is here |
| --- | --- |
| Nix | the repo IS a flake: every module, package, check and host |
| Lua | Hyprland's configuration language (`modules/home/desktop/hypr/lua/`) |
| QML | Quickshell's: the bar, the glance band, the OSD, the lock screen |
| Shell | glue, preferably inside a `.nix` (`writeShellApplication`), else a `.sh` beside its module (rule 7) |

**Why.** Every language costs a toolchain in the closure, a linter and a formatter in the hooks, a
test runner, its own idioms and its own failure modes, and that cost is paid every time a file is
reopened after months. Nix, Lua and QML are imposed by the tools the desktop runs on; Shell is the
glue all of them already speak. Python and TypeScript were choices, and the user's judgment on
21/10/2026 was that they are too heavy for this repo.

**An exception exists only where a HOST imposes the language**, the same reason Lua and QML are
here: a program that only accepts extensions written in X. It lives inside its feature's folder,
and, like every exception, carries a reason and a review date (rule 22). Third-party code the repo
only PACKAGES (an upstream Python app built with `buildPythonApplication`) is not code the repo
writes, and is not counted.

## The registered exceptions

| Path | Language | Host or reason | Review |
| --- | --- | --- | --- |
| `modules/home/shell/kitty/smart-paste.py` | Python | a kitty kitten: kitty runs kittens in its own Python | 21/10/2027 |
| `modules/home/desktop/vicinae/repositories/` | TypeScript | a Vicinae extension: Vicinae's API is React in TypeScript | 21/10/2027 |
| `tools/docs-site/` | TypeScript | the docs site (Next.js and Fumadocs), kept by the user's choice on 21/10/2026 | 21/10/2027 |

## Where the repo stands, and the way out

**MEASURED on 21/10/2026** (`wc -l` over tracked files; Python inside `.nix` counted between its
`''` delimiters, so it is close, not exact):

| Language | Repo-owned lines | Of which tests |
| --- | --- | --- |
| Python | about 2,760 after the lock's migration (1,183 in `.py` files, about 1,578 inline in `.nix`) | 279 |
| TypeScript, JavaScript | about 5,570 (the docs site 5,110, the Vicinae extension 459) | 1,094 |

**Done: the lock screen (21/10/2026).** `render.py`, `observe.py` and their four test files (about
2,800 lines of Python and shell) left with the move to QML; the lock path has no Python now.
[lockscreen.md](../desktop/lockscreen.md).

The rest, one phase at a time, each with its own plan when it starts:

| Phase | What | How |
| --- | --- | --- |
| A | The pre-commit checkers written in inline Python: ~~`prose-style`~~, ~~`docs-links`~~, ~~`rules-index`~~, ~~`data-syntax`~~, ~~`dead-config`~~ (the five shell since 22/10/2026), `router-ssot` | shell with `jq` and `rg`, or a check at Nix evaluation time; one per commit, since they ARE the quality gate |
| B | `modules/home/desktop/calendar/scripts/registry.py` and its test | validation and expansion in Nix, shell for `import-un` |
| C | `router-sync.py`, `wol-send.py`, Sunshine's `statsPy`, Vicinae's icon heredoc, `usage-audit`, `exposure-check`, `eval-metrics`, `repo-stats` | shell (`socat` for the magic packet), or Nix |
| C | `pkgs/razer-dpi` (ioctls on hidraw) | evaluated on its own: if shell cannot do it with dignity, it becomes an exception with a host-like reason |
| D | What only Python needed | the `ruff` hook, `python` in CodeQL's languages, the global `python3`/`uv` in `modules/nixos/packages.nix` if nothing else uses them |
