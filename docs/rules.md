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
| Layout | 4 `system/` and `home/` apart |
| Reproducibility | 3 declarative, 8 validate first, 13 the lock pins, 21 zero warnings |
| Ownership | 11 one source of truth, 14 one owner per artifact, 15 one owner per automation |
| State and secrets | 6 state is not declared, 12 secrets are a separate layer |
| Hygiene | 2 short comments, 7 no loose scripts, 16 dead config leaves, 19 packages named once, 22 exceptions expire |
| Writing and docs | 17 en-US and how, 20 the docs are a product |
| Working | 1 research first, 18 the agent contract is declared |

## 1. Research first

Always research the best practices and what the NixOS community is using most for each package/software (to have a reference and suggestions)

## 2. Comments are short

COMMENTS ARE SHORT, in EVERY file and with no exception. **AT MOST 2 LINES, ANYWHERE**: that is the cap for the module header AND for every comment inside it, per config, per package, per list item. The header says what the module is and where the detail lives. The detail itself goes to [`notes/`](notes/), never into the file. A comment records the why and the trap in one line, never the thing the code already says. THE REASON THIS RULE CHANGED TWICE: it first forbade the header block, then allowed it because the repo had them anyway, and the blocks grew until 36% of the tree was comment and one module carried a 123-line header (measured on 16/08/2026, 6062 comment lines in 16634). A header that long is not documentation, it is a wall you scroll past to reach the code, and the reasoning inside it was invisible to anyone reading `docs/`. So the reasoning MOVED instead of being deleted: `notes/<module>.md` holds the why, the measurements and what was tried and rejected, and the 2-line header points at it. The sweep landed on 16/08/2026: 1601 comment lines in 13299, 12%, with NOTHING deleted, only relocated. Whatever you touch, you shorten.

## 3. Declarative, never manual

Always declarative and never "manual" (so it works on any hardware later on)

## 4. `system/` and `home/` apart

Keep `system/` and `home/` apart: system level (services, drivers, root packages) in `system/`; the app **and** the user config in `home/` (`programs.*` when there is a module, otherwise `home.packages`). Never the same package in both.

## 5. Organized by category

Organize by category: each subject in its own subfolder with its `default.nix` (adding a module = 1 line in the category's `default.nix`; the top level does not change).

## 6. State is not declared

Nix = app + config; state is NOT declared: saves, Wine prefixes, app tokens/sessions stay out of the repo and go to the backup. That backup was restic, RETIRED on 24/09/2026 when the Google account blew past its 15 GiB quota, and until new storage arrives there is NONE. The rule still decides what stays out of git; what it stopped promising is that the state is safe somewhere ([restic](notes/boot-and-storage/restic.md)).

## 7. No loose scripts

No loose `.sh`: the logic lives in the build (Nix) or in systemd; runtime is a 1-line command (shellcheck at build time catches mistakes early).

## 8. Validate before applying

Validate before applying: `nixos-rebuild build` / `nix eval` OK and atomic commits per feature/task, before the switch.

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
module reads it, it is a system option and `home/` reads it through `osConfig` (the reverse does
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

SECRETS are a SEPARATE layer and the repo NEVER holds a credential: the source is Bitwarden, the delivery is sops-nix (root's age key). A consumer reads `/run/secrets/<name>` at RUNTIME, never at build time, because `/nix/store` is world-readable, so a secret interpolated into a derivation LEAKS. Editing a secret requires a `rebuild`, otherwise `/run/secrets` does not update.

## 13. The lock pins everything

The `flake.lock` PINS the dependency universe: no `nix-channel`, no fetch without a hash, no implicit "latest". Bumps only through `update`/`upgrade`, and `update` runs as the USER because that is who holds the SSH key for the private inputs, and the lock goes into the SAME commit as the change that required it, otherwise yesterday's build is not reproducible today.

## 14. One owner per artifact

ONE OWNER per artifact: if Nix generates the file, only Nix writes to it; if the app rewrites it at runtime, Nix does NOT manage it as a file, it uses an idempotent activation or an immutability marker (`ViewMode[$i]`). Two layers on the same file = SILENT DRIFT, the worst kind: nothing fails, it just ends up wrong. Real cases from this repo: hyprpaper (the HM module generating the old format against the config the daemon required, so a black screen for months), `~/.config/theme/*` (deleted as "temporary" when they were HM symlinks, so a boot with no session), `dolphinrc` (Dolphin rewrites it, so activation + `[$i]`).

## 15. Every automation has one owner

Every piece of AUTOMATION has an explicit and SINGLE owner: whoever starts it is declared (a systemd unit, the compositor's `exec-once`, a timer). An orphan process parented to some shell dies with it. And a single owner with NO FALLBACK is a point of failure: if the automation sustains remote access, it needs a safety net independent of the config that can break (that was the case with `graphical-session.target`, which only `exec-once` brought up).

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

**THE AGENT CONTRACT IS DECLARED, NOT RETYPED**: what I expect from Claude Code in EVERY project lives in `/etc/claude-code/CLAUDE.md`, generated by `system/services/claude-code.nix`, and NOT at the top of each prompt. This is rule 3 seen from the assistant's side, and manual has the failure mode manual always has: it works until the day I forget, and the day I forget produces a repo in two languages with one blob commit signed by a coauthor I did not want. THE THREE MANDATORY ONES ARE RULE 17's, promoted from this repo to the whole machine: incremental commits (one per feature/task), everything in en-US, and NEVER a `Co-Authored-By:` trailer. WHY THE MANAGED LAYER (`/etc`) AND NOT `$CLAUDE_CONFIG_DIR/CLAUDE.md`, which is the path everybody knows: the user file is PER ACCOUNT, so with the two accounts of `home/shell/claude-code.nix` it would be two copies of the same text drifting apart, and Claude Code WRITES to it (the `#` shortcut appends a memory to exactly that file), so declaring it would put two owners on one artifact (rule 14). The managed file is read-only by nature and CC only ever reads it. IT COSTS CONTEXT IN EVERY SESSION on this machine, this repo's included, so it holds the rules and NOTHING else: the reasoning behind each one is here, where whoever wants it can come and read. A project's own `CLAUDE.md` REFINES it and does not contradict it, because what is specific to a repo (its commands, its layout, its traps) belongs to the repo.

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
`notes/`) answers where a page lives, and the NAV (`docs-site/lib/navigation.ts`, by hand)
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

**THE EVALUATION EMITS ZERO WARNINGS**: a warning is a deprecation with a date on it that nobody wrote down, so it fails like an error. The gate and the canary run `nix flake check --option abort-on-warn true`: the gate stops a warning entering through my commit, and the canary, with every input at its head, turns an upstream rename into a red Monday a release before it breaks a `rebuild`. A warning that arrives with an `update` is fixed IN THE SAME COMMIT as the lock, never "later", which is rule 16's drift applied to someone else's deprecation. It is a CI flag and not `nix.settings`, because on the machine it would block the very `rebuild` that fixes it. The measurement and the sentinel proof: [`notes/repo/flake.md`](notes/repo/flake.md#zero-evaluation-warnings-abort-on-warn-29092026).

## 22. Every exception has a review date

**EVERY EXCEPTION HAS A REASON AND A REVIEW DATE**: an entry in an exception list (`dead-config`'s `ALLOWED` today, any allow list tomorrow) is `(reason, "YYYY-MM-DD")`. The reason says why it exists NOW; the date is the day the question comes back, when it is deleted or its date moves in a commit that says why. Without a date an exception list only grows, because nobody deletes a line that looks deliberate, and by 2032 "exception" and "leftover" read the same, which is rule 16 charging interest on its own escape hatch. The DATE is checked by the CANARY (`dead-config --expired`), never by the gate: a clock would make a hermetic, cached check pass on Monday and fail on Tuesday for the same commit. What this does NOT cover is a DECISION with its reasoning written down, such as the two statix lints turned off in `statix.toml`: that is policy, not an exception, and it changes by argument, not by calendar. The detail: [`notes/repo/dead-config.md`](notes/repo/dead-config.md#every-exception-has-a-review-date-rule-22-29092026).
