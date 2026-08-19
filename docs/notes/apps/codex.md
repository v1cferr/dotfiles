# codex

Modules: [`home/shell/codex.nix`](../../../home/shell/codex.nix),
[`pkgs/codex.nix`](../../../pkgs/codex.nix)

OpenAI's terminal agent. Two decisions: who owns `config.toml`, and where the binary comes from.

## Why `programs.codex.settings` is left empty

Home Manager 26.05 ships a `programs.codex` module, and its `settings` option is the obvious
thing to reach for: it renders an attrset into `CODEX_HOME/config.toml`. It is also the wrong
thing here, because that file lands as a symlink into `/nix/store` and **Codex WRITES to
`config.toml` at runtime**. The binary names the persistence paths itself:

```text
failed to persist model selection
failed to persist theme selection
failed to persist approvals reviewer update
failed to persist feature flags
```

So `/model`, `/theme`, `codex mcp add` and every approval the TUI remembers are writes into that
file. Pointed at the store, they do not degrade, they FAIL, measured on 0.147.0 against exactly
the file `settings` would have generated:

```text
failed to persist config at /nix/store/xicjbzz7cvhwdkdk86876jqxrwn1xl1q-codex-config
Read-only file system (os error 30) at path "/nix/store/.tmps8PdUu"
```

Failing loudly is the good case and it is still the wrong one: the option would trade every
runtime setting for the two lines it declares. That is rule 14, one owner per artifact.

The module's own guard is what makes leaving it empty work, and it is worth knowing: the file is
declared under `lib.mkIf (mergedSettings != { })`, so with `settings` at its default the module
generates NOTHING and the path stays free for the link below.

## The contract instead: a mirror versioned in the repo

`mkOutOfStoreSymlink` to [`home/shell/codex/config.toml`](../../../home/shell/codex/config.toml),
the same contract as [Claude Code's `settings.json`](claude-code.md) and VS Code's. Nix owns the
LINK, Codex owns the CONTENT, and what Codex changes lands as a `git diff` instead of drifting
where nobody can see it (rule 16).

**This needed measuring and not assuming**, because it USED to be broken: openai/codex#6646
reports the CLI replacing a symlinked `config.toml` with a regular file, and upstream first
answered that it was "by design". It was fixed before the issue closed on 19/01/2026. Verified
here on 0.147.0 with a `codex mcp add` through a symlink: the link kept its inode, stayed a
symlink, and the new `[mcp_servers]` table appeared in the file at the OTHER end. If a future
release regresses, the symptom is `~/.codex/config.toml` no longer being a symlink.

**Comments survive too**, which they do NOT in Claude Code's JSON: the header of this config was
still there after that write. Codex vendors `toml_edit` 0.24, a format-preserving TOML editor, so
a write edits the value in place instead of re-serializing the document.

`~/.codex` also collects things that are NOT config and are not declared: `auth.json`, session
transcripts, and the helper binaries Codex installs for its PATH aliases. All of it is state, so
it belongs to restic (rule 6), and `paths = [ "/home/v1cferr" ]` already covers it with no entry
of its own.

## The login is the subscription, not a key

`forced_login_method = "chatgpt"` pins the sign-in to the ChatGPT account, so the API-key path is
refused rather than offered. That is rule 12 read from the other side: an API key would be a
credential living in a shell or an env var, with nothing here to protect it. The subscription's
token goes to `~/.codex/auth.json`, written by Codex itself.

The key really is parsed and not politely ignored, which is worth proving because **Codex accepts
unknown top-level keys in silence**: an invented `bogus_key_test` loaded clean, while
`forced_login_method = "bogus"` failed with `unknown variant, expected chatgpt or api`. Feeding a
bad value on purpose is the only way to tell a live config line from a decorative one.

Logging in is `codex login`, once, interactively: it opens the browser against `localhost:1455`,
so it cannot happen at build time and does not need to.

## Auto mode is pinned, and where the two keys sit is load-bearing

`sandbox_mode = "workspace-write"` plus `approval_policy = "never"`: Codex runs commands on its
own, and the SANDBOX is what bounds that, not a prompt. Reaching outside the working directory or
onto the network fails instead of asking. Pinned rather than left implicit because the measured
default already WAS that sandbox with `on-request`, and a default is upstream's to change.

**Both keys must sit ABOVE the first table header**, which cost a wrong measurement on
19/08/2026. Appended at the END of the file they landed after `[tui]`, so TOML read them as
`tui.sandbox_mode` and `tui.approval_policy`, Codex ignored two keys it did not know THERE, and
`codex doctor` kept reporting `approval OnRequest` with the file looking correct. This is the
silent-unknown-key behavior from the section above, met from the other direction: the value was
right and the SCOPE was wrong. `codex doctor` is what settles it, since it prints the effective
policy rather than the file:

```text
sandbox   restricted fs + restricted network - approval Never
```

That matters more than usual here, because Codex WRITES to this file: anything appended by hand
after the app has added a `[projects.…]` or `[tui]` table is in that table, not at the root.

## Why the OFFICIAL binary and not nixpkgs

Upstream releases most days, and the third layer of the version strategy exists for exactly that.
On 19/08/2026 the count was: stable 26.05 on 0.146.0, `nixpkgs-unstable` on 0.147.0, upstream on
0.148.0. The middle layer was the first answer here and lasted a few hours, until Codex itself
printed the update banner for a release nixpkgs did not have yet. For an agent CLI the gap is
missing model support, not missing polish, so the layer that ends the question is upstream.

`fetchurl` on the GitHub release asset, with the version and hash rewritten by
[`codex-bump`](../repo/version-bumps.md) on every `update`. **NOT** a source build: nixpkgs
compiles Codex from Rust, so overriding its `src` would mean recomputing a vendor hash and
recompiling a 251 MiB binary on a project that tags almost daily. The published artifact is the
same thing without the wait.

**Take the `-package-` asset, not the bare `codex-` one**, and this is the trap that cost a broken
session on 19/08/2026. The bare tarball is the entrypoint ALONE, one 251 MiB file, and it looks
complete. It is not: Codex spawns a SECOND binary to run commands, `codex-code-mode-host`, and
looks for it NEXT TO its own executable. Without it every command dies with

```text
failed to spawn code-mode host <store-path>/bin/codex-code-mode-host: No such file or directory
Code mode will fail closed; enable `features.code_mode_host` and install `codex-code-mode-host`
```

which reads like a Codex bug and is a packaging bug. nixpkgs ships the extra binaries and that is
the detail this repo skipped when it left. `-package-` is the OFFICIAL layout, declared in a
`codex-package.json` at its root (`entrypoint`, `pathDir`, `resourcesDir`), so there is one asset,
one hash and nothing to assemble by hand.

Only `bin/` is installed. What is deliberately left behind:

| Dropped | Why |
| --- | --- |
| `codex-path/rg` | nixpkgs' ripgrep goes on the PATH instead, and it gets security updates |
| `codex-resources/bwrap` | same, and Codex takes a system `bwrap` from the PATH by its own message |
| `codex-resources/zsh` | the ONE dynamically linked file in the tarball, so it could not run here |

Dropping the zsh is verified and not a hope: with it gone Codex ran its command through
`/run/current-system/sw/bin/zsh -lc`, the system shell.

The rest is short because upstream ships STATIC musl. Measured before writing the derivation,
straight out of the tarball: no interpreter, `codex-cli 0.148.0`, clean `codex doctor`.

Two things still have to be added, and they are the two nixpkgs also adds:

| PATH entry | What breaks without it |
| --- | --- |
| `ripgrep` | the search, which reports `Install ripgrep or repair the bundled Codex package` |
| `bubblewrap` | the sandbox; Codex says it takes either a PATH `bwrap` or the bundled one |

`--inherit-argv0` on the wrapper, and NOT a plain shell wrapper, because Codex re-executes itself
as its own sandbox helper. Verified with `env -i`, where `rg` can only come from the wrapper:
`codex doctor` reported `ripgrep 15.1.0` and `restricted fs + restricted network`.

`dontStrip` is deliberate: it is a released artifact, and stripping it makes the binary stop
matching what upstream published for no gain.

**The in-app updater is not the path here.** The banner Codex prints ("Update available, run to
install") and its `codex update` subcommand both want to overwrite the binary, which is in the
read-only store. What updates Codex on this machine is `update`, the alias, like everything else.

**A third-party flake was passed over.** There are several that track Codex upstream and would
have cost one input instead of two files (`sadjow/codex-cli-nix` even rebuilds hourly). For a tool
that holds the ChatGPT session and executes shell commands, the fetch goes straight to the
publisher with a hash this repo pins, and the trusted set does not grow by one stranger. The
`pkgs/` file is 50 lines and the bump script is the one that was going to exist anyway.
