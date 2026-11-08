# tmux: Claude sessions the phone can join

Module: [`modules/home/shell/tmux.nix`](../../../modules/home/shell/tmux.nix)

The problem it solves: Claude Code runs in a kitty window on the PC, and a plain window takes one
client. Away from the desk I could not watch it from the phone (Termius), and at the desk I could
not join a run another terminal had started. tmux is scoped to that and nothing else: the other
terminals stay plain kitty, with kitty's own scrollback.

## How it is used

- **`ct`** always starts a NEW Claude, in a tmux session named after the folder: `dotfiles` first,
  then `dotfiles-2`, `dotfiles-3`, so two Claudes in one project never collide. Arguments pass
  through (`ct --resume`).
- **`ctw <task>`** starts a Claude for ONE task, in its own git worktree, branch and session
  (`betterpip-v1c-120`). See [One task, one worktree](#one-task-one-worktree-ctw).
- **`ca`** joins a running one: it attaches and opens tmux's own session list (`choose-tree`),
  picked with the arrows or a tap. The Termius host runs `ca` as its startup command.
- **Both at once** is the point. Both clients see the same screen and both can type.

Creating and joining were one command at first (`ct` joined the folder's session when it existed),
which made a second Claude in the same folder impossible without typing tmux by hand. Split on
24/10/2026.

That Termius setting lives in the app, outside Nix (rule 3), and is recorded here as the one manual
step.

## One task, one worktree: `ctw`

`ct` is "a Claude in this folder"; two of them in one repo edit the same files. `ctw` is "a Claude
for this task": each task gets its own checkout, so parallel tasks never touch each other's files.
`ca` stays the way back into any of them.

```bash
cd ~/projects/betterpip
ctw v1c-120                      # personal account, the default for ctw
ctw v1c-121
ctw v1c-122 --fai                # the FAI account, for this session only
ctw v1c-123 --model sonnet       # anything else goes to claude untouched
ca                               # pick any of them, from the PC or the phone
git worktree list                # one line per task, plus the main checkout
```

**The worktree is Claude Code's own** (`claude -w <task>`), not a script: it lives at
`<repo>/.claude/worktrees/<task>/`, on a branch `worktree-<task>` cut from the remote's default
branch. Measured on Claude Code 2.1.317 (08/11/2026). `ctw` only adds what Claude does not do: the
tmux session, the account and the guard below. The worktree path is ignored globally
(`/.claude/worktrees/` in `programs.git.ignores`), anchored to the repo root so no other `.claude/`
folder disappears from `git status`.

**Accounts.** `ctw` runs the same `claude-pessoal` / `claude-fai` wrappers as everything else, so
MCPs, secrets and `CLAUDE_CONFIG_DIR` come from [claude-code](claude-code.md) and nowhere else. The
flags are generated from that module's account list; the default (`pessoal`) is set in `tmux.nix`,
because these are mostly personal repos. Plain `claude` and `ct` keep the FAI default.

**The guard.** Each session records its worktree path in the tmux option `@ctw`. Running
`ctw v1c-120` again while that session is alive JOINS it (or switches to it, inside tmux) instead of
starting a second Claude on the same files. It finds the session from anywhere in the repo,
including from inside another worktree, because it always resolves the MAIN checkout first.

**Names.** `<repo folder>-<task>`, with `.` and `:` turned into `_` as in `ct`. Two repos with the
same folder name and the same task get `betterpip-v1c-120` and `betterpip-v1c-120-2`; the `@ctw`
path, not the name, is what tells them apart. Task ids take letters, digits, `-` and `_`: the id is a
folder, a branch and a session name at once, and a `.` or `/` breaks one of the three.

**Inside tmux** `ctw` never nests: it creates the session detached and switches the client to it.

**A start that fails at once** (most often a repo Claude has never trusted: run plain `claude` there
once first) keeps its dead pane, so the error stays on screen. Close it with `prefix x` or
`tmux kill-session -t <name>`.

### Resume, inspect, clean up

- **Session alive**: `ca`, or `ctw <task>` again.
- **Claude exited but the worktree was kept**: `ctw <task>` reopens the same worktree in a new
  session; add `--resume` (or `--continue`) to pick the conversation back up.
- **What exists**: `git worktree list` for checkouts, `tmux ls` for sessions.
- **Done with a task**: merge or push the branch, then quit Claude. On exit Claude itself asks
  whether to keep or remove the worktree, and removing also deletes the `worktree-<task>` branch.
  Something left behind is removed by hand, from the main checkout:
  `git worktree remove .claude/worktrees/<task>` (plus `git worktree unlock` first if git says it is
  locked) and `git branch -d worktree-<task>`. `ctw` deletes nothing on its own.

### What a worktree does not carry

- **Ignored files.** A worktree is a fresh checkout: no `.env`, no `node_modules`, no build output.
  A `.worktreeinclude` at the repo root (gitignore syntax) makes Claude copy the ignored files it
  matches into each new worktree; dependencies are installed again per worktree.
- **direnv.** `.envrc` is tracked, but the approval is per path, so each worktree needs its own
  `direnv allow` before the devShell loads.
- **Dev servers.** Every worktree starts the same server on the same port; run one at a time or give
  each its own port.
- **Nix flakes.** A flake inside a worktree evaluates THAT worktree's git tree, and only tracked
  files: a new file has to be `git add`ed before `nix build` sees it.
- **`rebuild` ignores the worktree.** It runs `nh os switch` on `programs.nh.flake`, the main clone,
  whatever folder it is typed in. For this repo: validate inside the worktree (`nix flake check`,
  or `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`), merge into `main` in
  the primary checkout, and only then `rebuild`.

### Why not a worktree manager

Claude Code already creates, reopens, locks and cleans up its worktrees, and asks before deleting
work. A manager (or a script of `git worktree add`) would be a second owner of the same directories
(rule 14). `--tmux` from Claude itself was not used either: it names and runs the session its own
way, outside the `ct` / `ca` contract the phone depends on.

## What the config changes, and why

| Setting | Value | Why |
| --- | --- | --- |
| `escapeTime` | 10 | Home Manager's module defaults to 500 ms, which lags every Esc in Claude Code; 10 is tmux's own default |
| `terminal` | `tmux-256color` | the module defaults to `screen`, which drops italics and truecolor |
| `historyLimit` | 50000 | a long Claude run outgrows the 2000-line default |
| `mouse` | on | so a swipe in Termius scrolls and a tap picks a session |
| `focusEvents` | on | Claude Code reacts to focus the same way it does outside tmux |
| `extended-keys` | on, `csi-u` | Shift+Enter reaches Claude Code as a newline instead of an Enter that submits |
| `terminal-features` | `xterm-kitty:RGB:extkeys` | tmux only uses what the outer terminal declares |

**`window-size` is left at its default**, `latest`: the window takes the size of the client that
was used last. Typing on the phone narrows Claude to the phone, and typing on the PC widens it back.
`smallest` would pin the PC to the phone's width for as long as the phone is attached. The defaults
were read from tmux 3.7b itself (`tmux -f /dev/null`) on 24/10/2026.

The Termius scrolling and the Shift+Enter behavior are REASONED from the man page and not yet
measured on the phone (24/10/2026).

## Rejected

Compared on 24/10/2026, against what I actually need: persistence plus several live clients on
one session, which is also how tmux is used at work for pairing.

- **zmx**: persistence only, one daemon per session, and a scrollback that stays native because it
  restores the screen through `libghostty-vt`. It was the favorite while the requirement was
  persistence alone. It lost on maturity (0.8.1, only in nixpkgs-unstable, and an upgrade that
  changes its IPC protocol leaves the running sessions unreachable) and because its README says
  nothing about how size works with two clients, which is the whole phone-plus-PC case.
- **Zellij**: the on-screen key hints are its selling point and they cost rows on a phone, while
  its Ctrl-heavy keys are awkward on a touch keyboard.
- **shpool**: persistence only, and one client per session, which rules out watching alongside the PC.
- **Claude Code's Remote Control**: tried before and not liked; it is not a terminal either.
- **mosh**: Termius supports it, but it needs UDP 60000-61000 open in the firewall and on the
  router, and tmux already keeps the session when SSH drops. Revisit only if reconnecting on the
  phone becomes a real annoyance.
