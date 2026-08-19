# codex

Module: [`home/shell/codex.nix`](../../../home/shell/codex.nix)

OpenAI's terminal agent. The whole page is about ONE decision: who owns `config.toml`.

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

## Why unstable

Upstream releases most days: on 19/08/2026 the latest tag was 0.148.0, from the day before, while
`nixpkgs-unstable` had 0.147.0 and stable 26.05 had 0.146.0. Stable freezes whatever landed at
branch-off and the gap only widens across the release, which for an agent CLI means missing model
support and not just missing features. The middle layer is the right one: close to upstream
without this repo taking on the packaging.
