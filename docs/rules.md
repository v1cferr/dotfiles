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

## 9. One theme palette

Everything in the TokyoNight theme, centralized in a Nix PALETTE of my own (`home/desktop/palette.nix`, option `my.theme.name`), so changing themes = 1 line (presets: tokyo-night/catppuccin-mocha/gruvbox-dark). nix-colors was DISCARDED: archived (apr/2026) and a base16 of only 16 colors does not reproduce the exact hexes.

## 10. One UI font

The UI FONT has its OWN SSOT, separate from the colors: `my.fonts.ui` in `system/hardware/fonts.nix` (next to the package, because a font is system level, rule 4; and fontconfig also needs the name, and a system module cannot read a home-manager option). Changing the font = 1 line + the package. A user-side consumer reads it through `osConfig.my.fonts.ui`, never as a literal.

## 11. One source of truth

SSOT ALWAYS: a value repeated in 2+ places becomes a `my.<domain>.<thing>` option and a consumer NEVER holds a literal. Today those are `my.theme.name`/`.palette` (colors, rule 9), `my.fonts.ui` (font, rule 10) and `my.services.<n>` (optional services). The option lives at the LOWEST level that needs it: if any module in `system/` consumes it, it is a system option and `home/` reads it through `osConfig`. The opposite does NOT exist (a system module cannot read a home-manager option). A HOT-RELOAD consumer (Quickshell/Hyprland) does not accept Nix interpolation, because the tree is a symlink: the module GENERATES a data file (JSON/Lua) that it reads, and then the only legitimate literal is the "file was missing" fallback. VALIDATE by swapping the option for a SENTINEL: rebuild, check that ALL consumers changed, revert and check that the store path came back identical.

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

**THE DOCUMENTATION IS A PUBLISHED PRODUCT, AND THE TREE IS NOT THE NAV**: `docs/` is built into a static site at <https://dotfiles.v1cferr.dev/> by `pkgs/docs-site.nix`, and that derivation lives in `packages`, so `checks.packages` builds it and the site is part of `nix flake check`: ONE definition of "the docs build", read by the gate, the pre-commit hook, the CI and the deploy, which is rule 14 applied to a renderer. THE RULE IS THE SEPARATION. The FILE TREE answers "where does this page live" and is split by FUNCTION at the top (the rules, the open items, the history, the notes, the guides, the ideas) and by SUBJECT inside [`notes/`](notes/), documented in [`README.md`](README.md) and [`notes/README.md`](notes/README.md). The NAV answers "how does a reader walk this" and lives in `docs-site/lib/navigation.ts`, written out by hand. **THE TREE NEVER MOVES TO MATCH A RENDERER**, and the temptation is real, because regrouping `docs/` by topic to mirror a sidebar looks like tidying. It is not, for three reasons in order of weight: sections named after the repo's own directories are the tree MIRROR that `notes/README.md` already measured and rejected (16 of the 51 pages of the day crossed the `system/` and `home/` boundary and 19 referenced two or more modules, because the ARTIFACT crosses); 221 pointers across 157 code files resolve INTO `docs/` and rule 2 made that pointer the only path from a module to its reasoning; and rule 17 wants a `git mv` history that survives, which 92 renames put a step into for a sidebar the nav expresses for free. A nav leaves with the generator that rendered it and the tree outlives it, so coupling the durable half to the disposable one is backwards, which is the whole of this rule in one sentence. WHAT ENFORCES IT IS THE BUILD AND NOT A NEW CHECKER, the same trade rule 7 makes for shell scripts: the site REFUSES to build when a page is left out of the nav, or a nav entry has no file, or two entries land on one URL, and it earned its keep on the first run by catching `notes/apps/spotify.md`, written and indexed nowhere. IT RUNS AT THE COMMIT AND IN THE GATE, and that placement is a measurement rather than a taste: under MkDocs it was a 7.12s `--strict` build, so it sat at `pre-push`, and since the Fumadocs migration it is a read of `docs/` plus one file on bare node, 0.14s measured, so the cheap unit is the right one. The gap was real for exactly one day: `notes/services/libvirt.md` was written, indexed in `notes/README.md` and left out of the nav, and nothing said so until the gate, two commits later. And EXISTING STOPPED BEING THE WHOLE TEST for a link: a target that leaves `docs/` is published as a GitHub blob URL, so it must be git-TRACKED and not merely present on disk, which `docs-links` now checks. RULE 13 DOES NOT STOP AT MY BUILD, it reaches the reader's browser: **the published site fetches NOTHING from a third party**, and the theme's defaults broke that twice on the day the site was born. Mermaid arrived from `unpkg.com/mermaid@11`, a moving pointer, and Roboto from `fonts.gstatic.com` on every page, which is worse for being invisible: an audit that greps `src=` never sees a font, because a font arrives through `href=`. Both are gone, and since the Fumadocs migration the BUILD is what refuses to publish a page reaching for a third party, instead of an audit somebody remembers to run. The reasoning is that a dependency somebody else can move is not less dangerous for running in a visitor's browser than in my sandbox. It is MORE, because I would never see it fail. AND THE GENERATOR IS REPLACEABLE ON PURPOSE, which stopped being a claim on 23/09/2026: MkDocs was frozen upstream, the bet was recorded with a trigger, and calling it cost one directory. What is generator-specific is `docs-site/` and one derivation, against 92 markdown files that any generator in this class consumes and that did not move by one byte. That is the same reason the tree did not move in the first place: the markdown is the asset, everything around it is scaffolding. The detail, the measurements and what was rejected: [`notes/repo/site.md`](notes/repo/site.md).

## 21. Zero evaluation warnings

**THE EVALUATION EMITS ZERO WARNINGS**: a warning is a deprecation with a date on it that nobody wrote down, so it fails like an error. The gate and the canary run `nix flake check --option abort-on-warn true`: the gate stops a warning entering through my commit, and the canary, with every input at its head, turns an upstream rename into a red Monday a release before it breaks a `rebuild`. A warning that arrives with an `update` is fixed IN THE SAME COMMIT as the lock, never "later", which is rule 16's drift applied to someone else's deprecation. It is a CI flag and not `nix.settings`, because on the machine it would block the very `rebuild` that fixes it. The measurement and the sentinel proof: [`notes/repo/flake.md`](notes/repo/flake.md#zero-evaluation-warnings-abort-on-warn-29092026).

## 22. Every exception has a review date

**EVERY EXCEPTION HAS A REASON AND A REVIEW DATE**: an entry in an exception list (`dead-config`'s `ALLOWED` today, any allow list tomorrow) is `(reason, "YYYY-MM-DD")`. The reason says why it exists NOW; the date is the day the question comes back, when it is deleted or its date moves in a commit that says why. Without a date an exception list only grows, because nobody deletes a line that looks deliberate, and by 2032 "exception" and "leftover" read the same, which is rule 16 charging interest on its own escape hatch. The DATE is checked by the CANARY (`dead-config --expired`), never by the gate: a clock would make a hermetic, cached check pass on Monday and fail on Tuesday for the same commit. What this does NOT cover is a DECISION with its reasoning written down, such as the two statix lints turned off in `statix.toml`: that is policy, not an exception, and it changes by argument, not by calendar. The detail: [`notes/repo/dead-config.md`](notes/repo/dead-config.md#every-exception-has-a-review-date-rule-22-29092026).
