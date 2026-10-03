# Rules

The INVARIANTS of this repo: what must stay true of every commit. A DECISION (which theme, which
generator, which file the agent reads) is not a rule, and lives in [decisions](decisions/README.md)
with its date and its status.

## How to read a card

Every rule is one card with the same four parts:

- **The rule**, in one or two sentences. **MUST**, **MUST NOT**, **SHOULD** and **MAY** mean what
  [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) says they mean. They are in BOLD because
  plain CAPS in this repo is emphasis, and the two must not be confused.
- **Why**: the reason, in at most three lines.
- **Enforced by**: the check that fails when the rule breaks, or `review` when only a reader
  catches it. [`rules-index`](notes/repo/rules-index.md) counts both.
- **Detail**: where the measurements, the incidents and what was rejected live. The long form of
  a rule is never deleted, it is moved there.

## The numbering is API

The tree cites a rule 512 times and 178 commit messages cite one too (measured 30/09/2026), and
those messages can never be edited. So a number is never reused and never shuffled: a new rule
goes in at the END, and a rule that dies keeps its heading, struck through, with the rule that
absorbed it. `rules-index` fails on a citation of a number that does not exist or was retired.

**How many rules there are is written nowhere but here**: a derived number has one owner, and
copying it only buys a second thing to forget.

## By theme

| Theme | Rules |
| --- | --- |
| Layout | 4 modules offer, hosts compose |
| Reproducibility | 3 declarative, 8 validate first, 13 the lock pins, 21 zero warnings |
| Ownership | 11 one source of truth, 14 one owner per artifact, 15 one owner per automation |
| State and secrets | 6 state is not declared, 12 secrets are a separate layer |
| Hygiene | 2 short comments, 7 no loose scripts, 16 dead config leaves, 19 packages named once, 22 exceptions expire |
| Writing and docs | 17 en-US and how, 20 the docs are a product |
| Working | 1 research first, 18 the agent contract is declared, 23 a claim carries its date |

## 1. Research first

Before adopting a package, a module or a pattern, I **MUST** look at what upstream recommends and
what the NixOS community actually uses, and the choice records what was compared and why the
others lost.

**Why**: a config meant to last until 2032 should stand on the idiomatic path, which is the one
that keeps being maintained, and a recorded "rejected because" keeps me from trying it twice.

**Enforced by**: review.

**Detail**: every note's "rejected" sections, and [decisions](decisions/README.md).

## 2. Comments are short

A comment **MUST NOT** run past 2 lines, anywhere: the module header, a config, a package, a list
item. The header says what the module is and points at its note in `docs/notes/`, which is where
the reasoning, the measurements and what was rejected live. A comment records the why or the trap,
never what the code already says. Whatever you touch, you shorten.

**Why**: by 16/08/2026 comments had grown to 36% of the tree and one header to 123 lines, a wall
scrolled past, with reasoning invisible to anyone reading `docs/`. It moved to notes, nothing
deleted.

**Enforced by**: `docs-links`, which fails on a module header in `modules/nixos/` or `modules/home/` longer than
2 lines or with neither a `docs/` pointer nor a plain "No note"; `eval-metrics` warns when the Nix
comment ratio passes its budget; the rest of the cap by review.

**Detail**: [the long form](notes/repo/prose-style.md#the-long-form-of-rule-2).

## 3. Declarative, never manual

Everything **MUST** be declared. A manual step is either a bug to remove, or something Nix cannot
reach (a BIOS setting, the router, Windows), written as a guide in [`guides/`](guides/).

**Why**: so the config works on any hardware later on, and a reinstall is a command, not a memory.

**Enforced by**: the boot test (`nix run .#vm-boot`) and the disk drill (`nix run .#disko-vm`),
which bring a machine up from the config alone; the rest by review.

**Detail**: [disaster recovery](guides/disaster-recovery.md).

## 4. Modules offer, hosts compose

A capability lives in `modules/`: system level (services, drivers, root packages) in
`modules/nixos/`, the app **and** its user config in `modules/home/` (`programs.*` when there is a
module, `home.packages` otherwise), and a package **MUST NOT** be in both. A machine, whatever it
runs, is a folder in `hosts/`, and a module that describes ONE device **MUST** be imported by the
host that has it, never by a shared `default.nix`. Software the repo packages goes in `pkgs/`,
what maintains the repo in `tools/`, and the outputs' implementation in `flake/`. Inside each
`modules/` half, every subject is a subfolder with its own `default.nix`, so adding a module is
one line there and the top level never changes.

**Why**: one `rebuild` applies both halves, so the split is about WHO needs a thing (root, a
service, or me); a host folder answers WHERE it runs, so a second machine never inherits this
desk's peripherals; and a fixed answer per question keeps a file findable at 150 modules and beyond.

**Enforced by**: `dead-config`, which fails on a module, host or flake file that nothing imports;
`docs-links`, which fails on a path under a retired root; the placement by review.

**Detail**: [decision 0009](decisions/0009-modules-hosts-tools-layout.md), and the decision per
package in the [README](../README.md#where-does-a-package-go).

## 5. ~~Organized by category~~

Retired on 30/09/2026 and folded into rule 4, which now says where a module goes AND how the
tree around it is organized. Its text was: Organize by category: each subject in its own subfolder with its `default.nix` (adding a module = 1 line in the category's `default.nix`; the top level does not change).

## 6. State is not declared

State (saves, Wine prefixes, app tokens and sessions) **MUST NOT** be declared: Nix holds the app
and its config, and state stays out of git, for a backup to keep.

**Why**: state is written by the app at runtime, so declaring it would put two owners on it
(rule 14). The backup that keeps it is restic on a local USB disk
([decision 0011](decisions/0011-local-usb-backup.md)), built on 03/10/2026 and on once the disk exists.

**Enforced by**: `dead-config`'s artifact check (a tracked build output or dropping); the rest by
review.

**Detail**: [restic](notes/boot-and-storage/restic.md).

## 7. No loose scripts

Logic **MUST NOT** live in a loose shell script: it lives in the build (`writeShellApplication`,
which runs shellcheck) or in systemd, and what runs is a one-line command. The one exception is a
script that runs on ANOTHER machine, which gets the shellcheck hook instead.

**Why**: a script in the build is checked every time it is built, and a loose one only when it
fails.

**Enforced by**: shellcheck at build time, and the `shellcheck` hook over every shell file.

**Detail**: [owfetch](notes/network/network.md#owfetch-why-a-script-and-not-fastfetch), the exception.

## 8. Validate before applying

Before a switch, the change **MUST** build (`nixos-rebuild build` or `nix flake check`) and be
committed as its own task.

**Why**: a switch that fails half-way is a slower loop than a build that fails, and a commit per
task is what makes the one bad change the one to revert.

**Enforced by**: the gate in the CI on every push; the local build by habit.

**Detail**: [the quality gate](notes/repo/flake.md#the-quality-gate-one-definition-three-consumers).

## 9. ~~One theme palette~~

Retired on 30/09/2026 and folded into rule 11, of which it was one application. The choice
it recorded is [decision 0001](decisions/0001-own-nix-palette.md), and its text is in
[ownership](notes/repo/ownership.md#the-former-rule-9).

## 10. ~~One UI font~~

Retired on 30/09/2026 and folded into rule 11, of which it was one application. The choice
it recorded is [decision 0002](decisions/0002-ui-font-in-system.md), and its text is in
[ownership](notes/repo/ownership.md#the-former-rule-10).

## 11. One source of truth

A value used in two or more places **MUST** become a `my.<domain>.<thing>` option, and a consumer
**MUST NOT** hold it as a literal. The option lives at the lowest level that needs it: if a system
module reads it, it is a system option and `modules/home/` reads it through `osConfig` (the reverse does
not exist). A hot-reload consumer (Hyprland, Quickshell) gets a GENERATED data file, and its only
legitimate literal is the fallback for a missing file. A change is proven with a SENTINEL value:
every consumer moves, and reverting restores the same store path.

**Why**: a repeated value drifts silently, one copy at a time. The theme palette
([decision 0001](decisions/0001-own-nix-palette.md)) and the UI font
([decision 0002](decisions/0002-ui-font-in-system.md)) are this rule applied, and were rules 9 and 10.

**Enforced by**: `dead-config` (an option nobody reads), `router-ssot` (the router's copies of a
value); a literal copied into a consumer by review.

**Detail**: [the long form](notes/repo/ownership.md#the-long-form-of-rule-11).

## 12. Secrets are a separate layer

The repo **MUST NOT** hold a credential. The source is Bitwarden, the delivery is sops-nix under
root's age key, and a consumer reads `/run/secrets/<name>` at RUNTIME, never at build time.
Editing a secret needs a `rebuild` for `/run/secrets` to change.

**Why**: `/nix/store` is world-readable, so a secret interpolated into a derivation leaks.

**Enforced by**: `gitleaks` (the staged diff at the commit, the whole history weekly),
`pre-commit-hook-ensure-sops` (no plain `secrets/*.yaml`), and `dead-config`'s two secret checks.

**Detail**: [secrets](notes/repo/secrets.md).

## 13. The lock pins everything

The `flake.lock` pins the dependency universe: no `nix-channel`, no fetch without a hash, no
implicit "latest". Bumps happen only through `update`, run as my user (who holds the SSH key for
the private inputs), and the lock **MUST** go in the same commit as the change that needed it.

**Why**: otherwise yesterday's build is not reproducible today.

**Enforced by**: Nix itself, which refuses an unhashed fetch in a pure evaluation; Scorecard's
Pinned-Dependencies for the workflows; the canary says when an `update` is safe.

**Detail**: [the flake](notes/repo/flake.md), and [version bumps](notes/repo/version-bumps.md).

## 14. One owner per artifact

A file has ONE writer. If Nix generates it, only Nix writes it; if the app rewrites it at
runtime, Nix **MUST NOT** manage it as a file, and uses an idempotent activation or an
immutability marker (`[$i]`) instead. What is not declared is given VISIBILITY in git: a mirror
regenerated by a command, or a direct link into the repo (`mkOutOfStoreSymlink`).

**Why**: two layers on one file is SILENT drift, the worst kind: nothing fails, it just ends up
wrong. It cost this machine a black screen for months (hyprpaper) and a boot with no session.

**Enforced by**: review; home-manager itself refuses to overwrite a file it did not create.

**Detail**: [the long form](notes/repo/ownership.md#the-long-form-of-rule-14).

## 15. Every automation has one owner

Every piece of automation **MUST** have one explicit starter: a systemd unit, a timer, or the
compositor's `exec-once`, never a process parented to some shell. An automation that keeps
remote access alive **MUST** also have a safety net that does not depend on the config that can
break.

**Why**: an orphan process dies with the shell that started it, and a single owner with no
fallback is one failure away from locking me out of the machine from far away.

**Enforced by**: review; the boot test (`nix run .#vm-boot`) fails on any unit that did not come up.

**Detail**: [the long form](notes/repo/ownership.md#the-long-form-of-rule-15).

## 16. Dead config leaves

Dead config **MUST** leave in the same commit that removed its use, and drift is a bug, not
tidying for later. The three forms all lie instead of failing: **dead** (declared, read by
nobody), **orphan** (the use left, the declaration stayed) and **drift** (the text describes a
system that no longer exists). An orphan **MUST** be found by reconciling the two RESOLVED ends
(for secrets, `config.sops.secrets` against `secrets.yaml`), never by a text `grep`, because a
declaration can be generated from data. A comment explaining what died is not drift; the
executable declaration is.

**Why**: the cost is charged to the next reader, who cannot tell necessary from leftover and
keeps it, so junk becomes permanent. And it bites: one unread password once left Caddy inert on a
switch, taking four services with it.

**Enforced by**: `dead-config` (7 checks), `deadnix`, `docs-links`, `rules-index`; `usage-audit`
reports, never fails.

**Detail**: [the long form and the incidents](notes/repo/dead-config.md#the-long-form-of-rule-16).

## 17. Written in en-US, and how

Everything in the repo **MUST** be written in en-US: code, comments, docs, option descriptions,
commit messages and file names. The closed list of pt-BR exceptions lives where each item is used,
with its reason. And every text follows the same habits:

- **Whatever you touch, you leave in en-US**, in the same commit; never a translation pass later.
- **Rename with `git mv`**, never delete and create: the history of a file is the product.
- **Commits** are conventional (`feat|fix|docs|chore(scope): subject`), in en-US, **one per
  task**, and **MUST NOT** carry a `Co-Authored-By:` trailer: who typed is not who decided.
- **No em dash and no emoji in prose.** A quoted literal (a program's output, a codepoint being
  discussed, a glyph used on screen) is the exception.
- **First person, not my name**: "my dotfiles"; second person is for the reader. A literal
  identifier (`v1cferr`, `ssh.v1cferr.dev`) is not a figure of speech.

**Why**: reach. The repo is public and the most detailed record of how I work, and it is meant for
people who do not read Portuguese. Half-translated is the worst of the three states.

**Enforced by**: `prose-style` (em dash, emoji, the trailer), `convco` (the commit grammar); the
language itself by review.

**Detail**: [the long form](notes/repo/prose-style.md#the-long-form-of-rule-17).

## 18. The agent contract is declared

What I expect from an AI agent in every project **MUST** be declared once, by Nix, and never
retyped into a prompt. It holds the rules only, which today are rule 17's three mandatory ones
(one commit per task, en-US, no `Co-Authored-By:` trailer); the reasoning stays in this repo. A
project's own agent file refines it and **MUST NOT** contradict it.

**Why**: this is rule 3 seen from the assistant's side. A contract typed by hand works until the
day it is forgotten. Where it lives is [decision 0003](decisions/0003-agent-contract-in-managed-layer.md).

**Enforced by**: the build, which generates `/etc/claude-code/CLAUDE.md` from
`modules/nixos/services/claude-code.nix`; `prose-style` refuses the trailer in every commit message.

**Detail**: [the long form](notes/apps/claude-code.md#the-long-form-of-rule-18).

## 19. A module names its packages once

A module that reaches for packages **MUST** name them once, in an `inherit (pkgs) ...;` that opens
its `let`, and use the bare names below. A namespace is resolved to the attribute used
(`inherit (pkgs.kdePackages) kconfig;`); `unstable` is the one that stays a namespace, so every use
still reads `unstable.foo`. A flat install list (`home.packages`, `environment.systemPackages`)
keeps its `with pkgs;`, and a module with one or two single uses **MAY** skip the block.

**Why**: "what does this module pull in" is answered by one block, the way a derivation's header
answers it, and a list that mixes packages with local bindings under `with` hides which name is
which. A sweep like this is proven textual when the system's `drvPath` does not move.

**Enforced by**: `deadnix`, since an inherited name nobody uses is an unused binding; the shape
itself by review.

**Detail**: [the long form](notes/repo/packages.md#the-long-form-of-rule-19).

## 20. The docs are a product

`docs/` is a published product, built into <https://dotfiles.v1cferr.dev/> by a derivation the
gate builds. Two layers stay apart: the FILE TREE (split by function at the top, by subject inside
`notes/`) answers where a page lives, and the NAV (`tools/docs-site/lib/navigation.ts`, by hand)
answers how a reader walks it. The tree **MUST NOT** move to match a renderer. Every page
**MUST** be in the nav, a link that leaves `docs/` **MUST** point at a tracked file, and the
published site **MUST NOT** fetch anything from a third party.

**Why**: a nav leaves with the generator that rendered it and the tree outlives it; hundreds of
pointers from the code resolve into `docs/`, and a `git mv` history is part of the product. A
dependency someone else can move is worse in a visitor's browser, where I never see it fail.

**Enforced by**: the site build (it refuses a page outside the nav, a nav entry with no file, two
entries on one URL, a third-party fetch) at the commit and in the gate; `docs-links`; `lychee` in
the canary for the external links.

**Detail**: [the long form](notes/repo/site.md#the-long-form-of-rule-20).

## 21. Zero evaluation warnings

The evaluation **MUST** emit zero warnings. A warning that arrives with an `update` is fixed in
the same commit as the lock.

**Why**: a warning is a deprecation with a date nobody wrote down. It is a CI flag and not
`nix.settings`, because on the machine it would block the very `rebuild` that fixes it.

**Enforced by**: `nix flake check --option abort-on-warn true`, in the gate (my commits) and in the
canary (every input at its head, a release before a rename breaks a `rebuild`).

**Detail**: [the measurement and the sentinel proof](notes/repo/flake.md#zero-evaluation-warnings-abort-on-warn-29092026).

## 22. Every exception has a review date

Every entry in an exception list **MUST** carry a reason and a review date. On the date it is
deleted, or its date moves in a commit that says why. A DECISION with its reasoning written down
(the two statix lints off in `.config/statix.toml`) is policy, not an exception, and changes by argument.

**Why**: without a date an exception list only grows, since nobody deletes a line that looks
deliberate, and by 2032 "exception" and "leftover" read the same.

**Enforced by**: `dead-config --expired` in the canary (`ALLOWED` and the `.config/gitleaks.toml`
allowlists), never in the gate: a clock would make a cached check change with no commit.

**Detail**: [dead-config](notes/repo/dead-config.md#every-exception-has-a-review-date-rule-22-29092026).

## 23. A claim carries its measurement and its date

A number or a claim about the system, in a note, a card or a commit message, **SHOULD** say how
it was measured and when (`MEASURED on 30/09/2026`), and a claim that was reasoned and not
measured **MUST** say so. A number that changes gets a new measurement and a new date, never a
silent edit.

**Why**: a number with a date can only be old, and a reader can tell; a number without one can be
wrong, and nobody can. This repo already works this way: the rule writes it down so the next page
does too.

**Enforced by**: review.

**Detail**: [eval-metrics](notes/repo/eval-metrics.md), whose budgets are the same idea as a check.
