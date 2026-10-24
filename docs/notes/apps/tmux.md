# tmux: Claude sessions the phone can join

Module: [`modules/home/shell/tmux.nix`](../../../modules/home/shell/tmux.nix)

The problem it solves: Claude Code runs in a kitty window on the PC, and a plain window takes one
client. Away from the desk I could not watch it from the phone (Termius), and at the desk I could
not join a run another terminal had started. tmux is scoped to that and nothing else: the other
terminals stay plain kitty, with kitty's own scrollback.

## How it is used

- **On the PC**, `ct` in a project folder starts Claude inside a tmux session named after the
  folder, or joins it if it already exists. Arguments pass through (`ct --resume`).
- **On the phone**, the Termius host runs `tmux attach || tmux new -s main` as its startup
  command, which joins the most recent session. `prefix + s` lists the others, and a tap picks one.
- **Both at once** is the point. Both clients see the same screen and both can type.

That Termius setting lives in the app, outside Nix (rule 3), and is recorded here as the one manual
step.

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
