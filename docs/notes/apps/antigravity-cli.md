# antigravity-cli

Modules: [`pkgs/antigravity-cli.nix`](../../../pkgs/antigravity-cli.nix),
[`home/packages.nix`](../../../home/packages.nix)

Google's terminal agent, `agy`. Three decisions: why it is here in place of the Gemini CLI, where
the binary comes from, and why NOTHING under `~/.gemini` is declared.

## Why not gemini-cli, which is what I went looking for

The third agent CLI here was supposed to be [gemini-cli](https://github.com/google-gemini/gemini-cli),
on the same terms as [Claude Code](claude-code.md) and [codex](codex.md): a subscription login, no
API key. That door is closed. Google
[announced](https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/)
the transition to Antigravity CLI on 19/05/2026, and on **18/06/2026 the Gemini CLI stopped
serving requests for free tier, AI Pro and Ultra**. Only paid enterprise licenses kept it.

**The upstream README still advertises the free tier with a personal Google account**, which is
why this note exists: that is drift on their side, not a second opinion. What settles it is the
CLI's own answer, in [issue #28846](https://github.com/google-gemini/gemini-cli/issues/28846):

```text
reasonCode: UNSUPPORTED_CLIENT
reasonMessage: This client is no longer supported for Gemini Code Assist for individuals.
To continue using Gemini, please migrate to the Antigravity suite of products
```

nixpkgs already carries the verdict too. `gemini-cli` evaluates with a marker, not just an
outdated version:

```text
Package 'gemini-cli-0.47.0' has the following problem: removal: Unpaid tier and
Google AI Pro/Ultra users: Gemini CLI was replaced by Antigravity CLI.
```

So the tool that keeps the "log in, never hold a key" contract is `agy`, and gemini-cli would only
have been an inert binary waiting for a `GEMINI_API_KEY` that rule 12 does not want here.

## The login is the account, not a key

Measured on 24/08/2026 against an isolated `HOME`: `agy` prints a Google OAuth URL, waits 60
seconds for the browser round trip, and ALSO accepts an authorization code pasted back into the
terminal. The redirect goes through `antigravity.google/oauth-callback`, so the same flow works
over SSH, where there is no browser to open.

The token then lives in the system keyring, reached over D-Bus (`org.freedesktop.secrets`), which
is the gnome-keyring this machine already unlocks at login. No credential of mine is in the repo
and none is in an env var, which is rule 12 read from the auth side.

The headless path exists and is deliberately NOT used: setting `modelProvider` to `gemini` plus a
`GEMINI_API_KEY`. Their docs are explicit that the variable alone does nothing, so there is no way
to end up on the API-key path by accident.

## Why the official binary and not nixpkgs

`antigravity-cli` IS in nixpkgs-unstable, and it is a `fetchurl` of the same published tarball,
so this is the codex question again with the same answer: the third layer of the version strategy.
Counted on 24/08/2026, the publisher's `latest` endpoint said **1.1.20** while `nixpkgs-unstable`
was on **1.1.13**. The nixpkgs bumps are not neglected, they are just slower than a preview
product: 1.1.11 on 05/08, 1.1.13 on 13/08, 1.1.19 on 23/08, and that last one is on master, not
yet in the channel. Upstream ships almost daily.

The artifact is the easy kind. One file in the tarball, `antigravity`, 197 MiB, Go, stripped, and
dynamically linked against glibc, so `autoPatchelfHook` is the whole build. It is installed as
`agy`, which is the name its docs, its errors and its own `install` subcommand use.

**No PATH dependency, unlike codex**: ripgrep is EMBEDDED in the binary, which its own error
strings give away (`no embedded ripgrep binary`, and a `third_party/rust/ripgrep/rg` build path).
That is why there is no wrapper here.

`versionCheckHook` runs `agy --version` against the store path at build time, which is what proves
the patchelf took: an unpatched binary cannot start at all.

**The in-app updater is not the path here**, same as codex: `agy update` wants to overwrite a
binary that lives in the read-only store, and `agy install`, which edits shell profiles for PATH
and aliases, is a job Nix already did.

## Nothing under `~/.gemini` is declared, and that is a measurement

Two facts, in this order: there is nothing to declare YET, and the codex contract would not hold
if there were.

**Sparse persistence is why the repo looks empty next to codex's.** Their docs are explicit that
the CLI writes only the values that DIFFER from the defaults, so with the settings untouched there
is no `settings.json` at all. Measured after my own login, on 1.1.20: `~/.gemini/config/config.json`
holds ONE generated key, `mcp_config.json` is 0 bytes, and no settings file exists. Codex is the
opposite: `config.toml` is there from the first run and the app persists into it, which is what
makes a mirror worth having THERE.

**And the symlink does not survive a write**, tested on 1.1.20 against the path their docs name,
`~/.gemini/antigravity-cli/settings.json`:

| Step | Result |
| --- | --- |
| Hand-written keys reached through a symlink | READ and honored: `colorScheme` and `showTips` both survived |
| The same run, afterwards | the path is a REGULAR file, re-serialized pretty-printed by the app |
| The mirror at the other end | untouched, still holding what I wrote |

`~/.gemini/config/config.json` behaves the same way: pointed at a mirror holding `{}`, the first
write detaches the link and the mirror stays at `{}`. The key it rewrites there is
`userSettings.remoteControlHostname`, a generated name (`nixos-kingston-fiery-ion`, then
`-orbital-mars`, then `-deep-drift`), which also says what that file is: the app's scratch space,
not my config.

So editing by hand WORKS and a symlink does not, which is the opposite pair from codex. The day a
setting here is worth owning (`toolPermission`, `enableTerminalSandbox`, `enableTelemetry`, or an
MCP server), the mechanism is rule 14's other half: an idempotent activation that merges my keys
into whatever the app left, never a link.

**The login is not under `HOME` at all**, which the same test proved by accident: a run with `HOME`
pointed at an empty scratch directory answered the prompt anyway. The token is in the keyring,
reached over D-Bus, and the keyring is per USER, so isolating `HOME` does not isolate auth and no
file under `~/.gemini` carries the credential.

So the declaration is the PACKAGE and nothing else. Everything the tool keeps is state and belongs
to restic (rule 6), which `paths = [ "/home/v1cferr" ]` already covers:

| Path | What it holds |
| --- | --- |
| `~/.gemini/config/` | `config.json`, `mcp_config.json`, per-project files, a `.migrated` marker |
| `~/.gemini/antigravity-cli/` | `settings.json` and `keybindings.json` once touched, plus conversations, knowledge, brain, logs, crashes |
| `~/.cache/ms-playwright-go/` | the browser runtime it downloads on its own for the browser tools |

**A correction worth keeping** (24/08/2026, same day): I first read the missing
`settings.json` plus the `.migrated` marker next to `config.json` as the settings file having
MOVED, and wrote here that their docs described a previous layout. Wrong. The documented path is
live, and what keeps it from existing is the sparse persistence above, proven by writing one by
hand and watching both keys take effect. `config.json` and `settings.json` are two different files
with two different jobs, and only the second one would ever be mine.

## Where an MCP server would go

`~/.gemini/config/mcp_config.json`, created empty on the first run. That is the file that would
point `agy` at a shared MCP server, which is the reason I am looking at basic-memory: one memory
for the three agents instead of one archive each.

It is app-owned like everything else above, so declaring it means the OTHER half of rule 14, an
idempotent activation that merges the keys I own into whatever is there, never a symlink. Nothing
of that exists yet, and it should not until there is a server worth pointing at.
