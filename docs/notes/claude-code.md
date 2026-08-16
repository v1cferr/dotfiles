# claude-code

Modules: [`home/shell/claude-code.nix`](../../home/shell/claude-code.nix),
[`system/services/claude-code.nix`](../../system/services/claude-code.nix)

Two subscriptions on one machine, one shared archive, and the rules every project inherits.

## The problem: two accounts, one config directory

There are TWO subscriptions here (FAI/nonprofit and personal) and Claude Code keeps the login, the
MCP servers and the settings in a single config directory. Running both in the same directory
would mean logging in again on every switch. The way out is `CLAUDE_CONFIG_DIR`: one directory per
account, and switching accounts means switching the variable.

| Path | What it is |
| --- | --- |
| `~/.claude-fai` | FAI / nonprofit, and the DEFAULT |
| `~/.claude-pessoal` | personal |
| `~/.claude` | NOT an account: the shared ARCHIVE (`projects/`) |

**There are two accounts and not three**, which is a correction from 11/08/2026. The first version
of this module created an EMPTY `~/.claude-fai` next to `~/.claude`, which already WAS the FAI
account (`oauthAccount.emailAddress` matched, a nonprofit premium seat). That would have been two
logins for the same subscription, with the third "account" existing purely by accident of naming.

Now plain `claude` LANDS ON FAI, because `CLAUDE_CONFIG_DIR` is exported into the session. That
holds for everything calling the binary without going through a wrapper: the VS Code extension, a
script, cron. The other account is `claude-pessoal`, which overrides the variable.

## Why the archive stays in `~/.claude`

`projects/` (transcripts plus memory, 200 MB across 13 projects) belongs to the MACHINE, not to a
subscription. Keeping it on the canonical path means third-party tooling that looks for the
standard (`ccusage` and friends) finds it by itself, and retiring an account one day does not
orphan the archive.

**And that is why `~/.claude` cannot be the config folder**, however tempting it looks now that it
already is FAI. The `.claude.json` (project and MCP config, distinct from `settings.json`) lives at
the ROOT of `CLAUDE_CONFIG_DIR`. Without the variable it is the home's `~/.claude.json`; with it
pointed at `~/.claude` it would become `~/.claude/.claude.json`, a SECOND file diverging from the
first. Verified on 2.1.222: along with the symlink test, `claude mcp add` wrote exactly inside
`CLAUDE_CONFIG_DIR`.

History and memory are SHARED on purpose: each account's `projects/` is a symlink to the canonical
archive, so any account resumes the same conversations and reads the same memories. On Arch this
was a `_claude_share_projects` function in `.zshrc`, imperative and running on every shell open;
here it is a declared symlink (rule 3). One price to know: `ccusage` cannot separate cost per
account, because it reads the shared archive.

## A wrapper, not an alias

An alias only exists in an INTERACTIVE zsh, so `claude-fai` did not work over non-interactive SSH,
inside a script, in a VS Code task or in a Hyprland keybind. The wrapper is a binary on the PATH,
and rule 7 asks for the logic in the build.

For free, the wrapper PINS the claude version (the package's own store path) instead of depending
on which `claude` the PATH resolves first, which matters here because this machine has an orphan
native install in `~/.local/bin`, the one `claude doctor` complains about.

Plain `claude` became a wrapper too (it used to be the raw binary), because plain `claude` IS the
FAI account: without that, the Azure MCP would only appear for whoever remembered to type
`claude-fai`, and never in the VS Code extension. The `claude` package no longer enters
`home.packages`, since two `bin/claude` would collide at activation; it is referenced through
`lib.getExe` inside the wrappers.

## settings.json is versioned, and the atomic-write guard is what makes it safe

Same contract as VS Code and `hyprland.lua`: `mkOutOfStoreSymlink` to the REAL file in the repo,
mutable, so the TUI's `/config` keeps working and every adjustment lands as a `git diff` instead
of invisible drift (rule 16). A `programs.*` generating into the store does NOT work, because the
store is read-only and CC writes to that file.

Measured on 11/08/2026 on 2.1.222: CC writes `settings.json` ATOMICALLY (tmp plus rename), and a
rename over a symlink would REPLACE the link with a regular file, disconnecting the repo silently.
But it resolves the realpath FIRST: the link survived intact and what changed inode was the TARGET
(593793 to 593844, through `claude auto-mode reset`). If CC ever loses that guard, the symptom is
`~/.claude-fai/settings.json` no longer being a symlink.

**No comments inside the JSON**, on purpose: CC rewrites the whole file on save (it is not JSONC
like VS Code's) and would erase them.

`theme: dark-ansi` is not neutral, it is as TokyoNight as it gets: it tells the TUI to use the
terminal's 16 ANSI colors, which in this repo's kitty ALREADY are the `my.theme` palette (rule 9).

**How the FAI settings were built**: the personal one came from Arch whole; the FAI one is a MERGE
of the Arch file with what `~/.claude` had in use, namely the `github`, `atlassian` and
`frontend-design` plugins. Taking only the Arch version would have SILENTLY turned off three
plugins that were on, which is the kind of loss nobody connects to the migration two days later.

What died in the crossing (rule 16): the `permissions.allow` for `mcp__pencil`, and the two user
MCP servers present in both accounts' `.claude.json`, `pencil` (an AUR package that does not exist
here) and `atlassian` (through `npx mcp-remote`, today done by the official plugin). Migrating a
permission for an MCP server that never comes up would be declaring the nonexistent.

## The Azure MCP is FAI-only, and the delivery path was the hard part

The Azure MCP Server ([`pkgs/azure-mcp.nix`](azure-mcp.md)) enters FAI ONLY, because the cloud is
the work one. The personal account has nothing to do with it, and 68 extra tools cost context in
every session. That is why `mcp` became a field of `profiles`: an account that declares nothing
gets no flag.

Delivery is the wrapper's `--mcp-config`. Three alternatives were discarded, each for a concrete
reason:

- **the repo root's `.mcp.json`** (which serves the two Cloudflare MCP servers) is PROJECT scope,
  so Azure would only exist when running `claude` inside the dotfiles, which is exactly where we
  will never touch Azure;
- **user scope in `.claude.json`** is app state, and CC rewrites the whole file, so declaring
  there is rule 14's recipe for drift;
- **`/etc/claude-code/managed-mcp.json`** looks like the right place, being the sibling of the
  `managed-settings.json` we already use, and it is a TRAP: whoever deploys that file gains
  EXCLUSIVE control, and CC stops loading EVERYTHING else, including the MCP servers of the
  `github` and `atlassian` plugins that are in use. It would gain Azure and lose two.

## The system side: what has to be IMPOSED

[`system/services/claude-code.nix`](../../system/services/claude-code.nix) holds the two things
that cannot be merely suggested, both in `/etc`, which has the highest precedence and is read-only
by nature:

**The lifecycle hooks** feed the Discord Rich Presence: six events POST to the local daemon
([`home/services/claude-discord-rpc.nix`](../../home/services/claude-discord-rpc.nix)), which
paints the card. Same format `claude-presence setup` would write, only declared. The path is FIXED
in `/etc`, outside `CLAUDE_CONFIG_DIR`, so they hold for both accounts at once. `SessionStart` is
sync and the rest are async, so they do not block CC. The hook is wrapped in a
`writeShellApplication` because CC runs it with the USER's PATH, which may not have `jq`; the
`exec` makes the wrapper disappear and leaves the real script.

The reason `/etc` and not the user's `settings.json`: CC WRITES to the user's settings at runtime
(`/config`, permission approvals), so it can never become a read-only symlink into the store. The
managed file is read-only by nature and does not fight those writes.

**The global rules** (`/etc/claude-code/CLAUDE.md`, 15/08/2026) are rule 3 applied to the agent
contract. The three mandatory ones (incremental commits, everything in en-US, never a
`Co-Authored-By:`) were being RETYPED BY HAND at the top of every prompt, which is the definition
of manual: it works until the day you forget, and what comes out of that day is a repo in two
languages with one blob commit signed by a coauthor.

Why `/etc/claude-code/CLAUDE.md` and not `$CLAUDE_CONFIG_DIR/CLAUDE.md`, which is the path
everybody knows: the user one is PER ACCOUNT, so with two accounts it would be two copies drifting
apart, and CC WRITES to it, because the `#` shortcut appends a memory to exactly that file. Nix
owning it would break the shortcut and rule 14. The managed one CC only ever READS.

Measured on 2.1.222, in the bundle itself, because a memory file that is never read fails SILENTLY
and looks exactly like a rule being ignored: the memory loader resolves "Managed" to
`join(fU(), "CLAUDE.md")` and `fU()` returns `/etc/claude-code` on Linux. It is read
UNCONDITIONALLY, unlike the User and Project layers, which are gated by settings, and it does not
REPLACE the project's `CLAUDE.md`, it loads alongside it.

Discarded, and it is the near miss: `managed-settings.json` has a `claudeMd` STRING field that
does the same job with no second file. It loses on the diff, since the markdown would become a
JSON one-liner with escaped newlines, unreadable in a `git diff` and unreachable for markdownlint.

**Keep that file short.** It enters the context of EVERY conversation on this machine, so it is
the most expensive documentation in the repo per line. It holds the rules and nothing else; the
reasoning lives in [`../rules.md`](../rules.md).

## What is NOT declared here

- `.credentials.json` (each account's OAuth token), a secret AND state: never versioned, never
  declared. A new account means one `/login` (rules 6 and 12).
- `.claude.json`, `history.jsonl`, `sessions/`, `plugins/`, `cache/`: app state written at
  runtime, so restic and not git (rule 6).
- `~/.claude/projects/`, which is the TARGET of the symlinks. Nix owns the links; the content
  belongs to the app (rule 14).
- The rest of `~/.claude` (history.jsonl, settings.json, sessions/, shell-snapshots/), leftover
  from when it was an account. What was worth keeping was copied to `~/.claude-fai` at the turn,
  and the rest gets pruned once the new account proves it walks. Noted in
  [`../open-items.md`](../open-items.md).

## The `--` terminator rule is the opposite of the intuition

Measured on 2.1.222. `--mcp-config` is VARIADIC (it accepts N files), so it swallows everything
after it until it finds a token starting with `-`.

- With **no** terminator, `claude-fai mcp list` dies with `MCP config file not found: …/mcp`,
  because it read `mcp` and `list` as two more config files.
- With the terminator ALWAYS, `claude-fai --version` opens a SESSION with `--version` as the
  prompt instead of printing the version.

Hence the `case` in the wrapper: what starts with `-` (or nothing, the interactive TUI) goes
WITHOUT the terminator; a bare word (a subcommand or a prompt) goes WITH it.

`exec` is there so the wrapper leaves the process tree and only the real claude remains, which is
what makes signals and the TUI's TTY arrive directly.

## The env var only takes effect after a RELOGIN

Measured on 11/08/2026, with the switch already applied and `CLAUDE_CONFIG_DIR` still empty in a
freshly opened zsh. A new terminal is NOT enough.

The mechanism: the variable is written into `hm-session-vars.sh`, which `~/.zshenv` loads, and the
file guards itself with `__HM_SESS_VARS_SOURCED=1` so it does not reload in a subshell. That mark
is EXPORTED, so every child of the graphical session is born with it and skips the whole load.
Proven with `env -u __HM_SESS_VARS_SOURCED zsh -i -c`: without the mark, the variable appears.

Same family as the `NH_FLAKE` trap in [`shell.md`](shell.md).

`programs.zsh.sessionVariables` was tried as a second layer and does NOT help: it lands in the
SAME `~/.zshenv` and brings its own guard (`__HM_ZSH_SESS_VARS_SOURCED`), which the session
already exports even when the repo does not use the option, because home-manager always emits the
block. Two layers with the same flaw; one honest layer remained.

**Until the relogin, what delivers the right account is the WRAPPER**, which exports the variable
itself. That is the strongest argument for the wrapper existing: it does not depend on the session
environment having been rebuilt.

## Two operational details

**The Azure MCP mode.** `--mode namespace` (azmcp's default) exposes ONE tool per service, 68 in
total. `all` would explode into hundreds and `single` would leave just one with an extra routing
hop. To trim it, `--namespace storage --namespace keyvault …` limits it to the named services.

**`azure-mcp` is also on the PATH as a command**, and that is not convenience: the Azure login is a
device code and it HAS to happen outside Claude Code, because inside a session the code comes out
on the MCP server's stderr, where nobody reads. The closure cost is zero, since the MCP config
already references that store path.

**Restoring an account backup**: the activation FAILS if `~/.claude-<account>/projects` already
exists as a real directory (`existing file would be clobbered`). Restore the CONTENT into
`~/.claude/projects`, never the account folder.
