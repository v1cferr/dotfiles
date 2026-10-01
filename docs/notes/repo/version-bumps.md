# vendored-bump and the vendored package layout

Modules: [`tools/vendored-bump/package.nix`](../../../tools/vendored-bump/package.nix),
[`tools/vendored-bump/mk-vendored-bump.nix`](../../../tools/vendored-bump/mk-vendored-bump.nix),
[`pkgs/vscode/bump.nix`](../../../pkgs/vscode/bump.nix),
[`pkgs/curseforge/bump.nix`](../../../pkgs/curseforge/bump.nix),
[`pkgs/codex/bump.nix`](../../../pkgs/codex/bump.nix),
[`pkgs/antigravity-cli/bump.nix`](../../../pkgs/antigravity-cli/bump.nix)

Every package that is in neither nixpkgs nor a flake follows ONE layout, and one runner keeps all
of them on upstream's latest without anybody editing a hash by hand. They share a reason and differ
only in how they ask "did it change?", so they live on one page.

## The structural reason they exist

Rule 13 pins the dependency universe: no fetch without a hash, no implicit "latest". That rule has
a consequence people miss: **a src with a locked hash never updates itself.** What exists is not
an "input that follows upstream", it is an AUTOMATED BUMP.

All four run from the `update`/`upgrade` alias
([`modules/home/shell/zsh.nix`](../../../modules/home/shell/zsh.nix)), before `nix flake update`, so "always on
the latest" happens at rebuild time. All four are a NO-OP when already current, because they run
on every `upgrade`.

## One runner, and the list is DERIVED

Each bump is the `passthru.updateScript` of the package it bumps, the nixpkgs convention for "this
package knows how to update itself". VS Code's replaces nixpkgs' `update-vscode.sh`, which edits
nixpkgs and not this repo. `vendored-bump` is built from `overlayLocalPkgs` in
[`flake.nix`](../../../flake.nix): every local package whose `updateScript` is not null, plus VS
Code (an override of unstable's, so not in `localPkgs`), each called by STORE PATH.

Until 26/09/2026 the alias listed the four by NAME, which cost two things. Adding a package meant
editing a 250-character string in `zsh.nix`, and each script had to be on the PATH, so one that was
only a flake package broke the chain at its `&&` (`codex-bump: command not found`, 24/08/2026).
Now a new vendored package bumps by declaring `passthru.updateScript`, and nothing else changes.

The contract differs from nixpkgs' on one point: the runner passes the repo path as `$1`
(rule 11), where nixpkgs runs the script from its own root. And it only takes the DERIVATION form.
A list or attrset `updateScript` is a `throw` at eval time, never a silent skip.

**`nxbender` opts out with `updateScript = null`.** `buildPythonApplication` brings a default
`nix-update` on its own, and its src is a pinned commit carrying 3 patches: a bump there is a human
reading the diff, not a script.

## The layout every vendored package follows

A package that is in neither nixpkgs nor a flake lives in a folder of its own, always the same
three files:

```text
pkgs/<name>/
  package.nix   reads version, url and hash from source.json; passthru.updateScript = ./bump.nix
  source.json   { "version", "url", "hash" }, the ONLY file a bump writes
  bump.nix      mkVendoredBump { pname; latest; resolve; }
```

[`mkVendoredBump`](../../../tools/vendored-bump/mk-vendored-bump.nix) owns everything the four scripts used to
repeat: reading the current version, rejecting an implausible answer, the no-op when current, the
write through a temp file and the suggested commit. A package answers only the two questions that
are really its own. `latest` prints upstream's newest version, as cheaply as upstream allows.
`resolve` prints the `url` and `hash` of that version, through one of two helpers: `prefetch URL`
downloads and hashes, and `sri ALGO HEX` converts a hash upstream already publishes.

**JSON and not `sed` on a `.nix`.** The old scripts found the version with a regex on the source
and rewrote it the same way, so a reformat by nixfmt or a renamed attribute broke the bump
silently. `jq` reads and writes a structure, and `lib.importJSON` is the only reader on the Nix
side. The `url` is stored WHOLE even when it is derivable from the version, so no package carries
a second format of the same URL (rule 11), and antigravity's opaque build id stops being a field.

### Adding one

Start from the package closest in SHAPE, since `latest` and `resolve` are what differ:

| Upstream publishes | Copy from |
| --- | --- |
| a GitHub release asset | [`pkgs/codex/`](../../../pkgs/codex/bump.nix): a HEAD on `/releases/latest`, `prefetch` |
| a version API with the hash in it | [`pkgs/vscode/`](../../../pkgs/vscode/bump.nix): one JSON kept in `$tmp`, `sri` |
| a manifest per release | [`pkgs/antigravity-cli/`](../../../pkgs/antigravity-cli/bump.nix): `sri` on the published sha512 |
| only a pointer url | [`pkgs/curseforge/`](../../../pkgs/curseforge/bump.nix): the version from somewhere cheap, `prefetch` |

1. Create `pkgs/<name>/` with the three files. `pname` in `bump.nix` MUST be the folder name,
   because that is how the skeleton finds `source.json`. Start `source.json` as the placeholder
   `{"version": "0", "url": "", "hash": ""}`, since `0` is never the latest.
2. Add `<name> = final.callPackage ./pkgs/<name>/package.nix { };` to `localPkgs` in
   [`flake.nix`](../../../flake.nix), and the `home.packages` entry in the app's module.
3. `git add` the folder (a flake only sees tracked files) and run `update`: the runner picks the
   new bump up and fills `source.json` for real. Measured on 26/09/2026 against codex, the
   placeholder came back byte-identical to the committed file.
4. `rebuild`, and commit the package with its filled `source.json`.

Nothing else changes: not `zsh.nix`, not the flake's `packages`, not any list.

## Why not a community flake or nvfetcher

Researched on 26/09/2026 (rule 1), and both lost on measurement, not taste:

- **[numtide/llm-agents.nix](https://github.com/numtide/llm-agents.nix)** packages codex and
  antigravity-cli with a daily CI and a binary cache. At its HEAD that day its `antigravity-cli`
  was on 1.2.11 while this repo was already on 1.2.12, and its codex is compiled from source with
  LTO turned off, so it is not the artifact OpenAI ships. Going upstream directly is FASTER here,
  and it is the third layer of the version strategy anyway.
- **[nvfetcher](https://github.com/berberman/nvfetcher)** centralizes sources in a TOML, but it
  hashes by downloading, which throws away the two cheap answers below (the `.deb` range request
  and the published sha512). It would also add a generated file and a tool to do what 60 lines of
  shell already do.

## Where they differ

Only in the two answers, which is the point of the layout:

| | vscode | curseforge | codex | antigravity-cli |
| --- | --- | --- | --- | --- |
| Upstream URL | versioned (`/1.139.1/linux-x64/stable`) | a POINTER (`curseforge-latest-linux.AppImage`) | versioned (`/rust-v0.157.1/…musl.tar.gz`) | versioned, plus an opaque build id |
| `latest` asks | the official update API, `productVersion` | the `control` file of the `.deb` | the redirect of `/releases/latest` | a `latest` file holding the bare version |
| `resolve` hashes by | `sri`: the API publishes the sha256 | `prefetch`: 139 MiB, only on a new version | `prefetch`: 93 MiB, only on a new tag | `sri`: the manifest publishes the sha512 |

**VS Code.** The URL is versioned because `/latest/` is a pointer that broke the eval on every
release ([flake](flake.md) has the CI failure). `latest` reads `productVersion` and NOT `version`
from the API, because the second one is the commit hash (`df53daa…`). The API response is kept in
`$tmp`, so `resolve` converts the `sha256hash` of the SAME answer and a release landing between the
two questions cannot pair one version with another's hash.

**CurseForge.** Overwolf publishes no versioned URL, so the hash is the only anchor and it has to
be RECOMPUTED. Downloading 139 MiB on every `update` to find out nothing changed would be absurd,
and there is no version API, so what answers "did it change?" is a **256 KiB range request on the
`.deb`**: the `control` file sits in the first few KiB and carries the version. The AppImage is
only downloaded when the answer is yes.

Measured on 14/08/2026: both artifacts are published at the same instant and carry the same
release (`1.316.0~37372-37372` in the `.deb`, `1.316.0-37372.37372` in `X-AppImage-Version`); the
strings differ only in formatting, hence the normalization. If they ever get out of sync, the worst
case is downloading the AppImage for nothing: the skeleton compares and rewrites, it does not break.

One shell trap in there: the control member goes through a FILE and not a pipe, because GNU tar
only autodetects the compression when it can seek, so `ar p … | tar -xO` dies with
`Archive is compressed. Use -J option`. From a file it works it out on its own, which also survives
the day Overwolf swaps `.xz` for `.zst`.

**Codex.** A GitHub release is the easy case of both halves: the asset URL is versioned, so it is
immutable, and "did it change?" costs ONE HEAD request, because `/releases/latest` REDIRECTS to the
tag (`…/releases/tag/rust-v0.157.1`). The REST API would answer the same and spend one of the 60
anonymous calls per hour. The tag carries a `rust-v` prefix because that repo releases more than
one artifact line; a tag of another shape leaves the whole URL behind, which the skeleton's
plausibility check rejects. Prereleases never reach it, since `/releases/latest` skips them.

**Antigravity.** Google publishes a `manifest.json` per release with the URL and the **sha512 of
every platform**, which is why its `source.json` pins a `sha512-` hash where the others pin
`sha256-`: taking the algorithm they publish is what makes the 56 MiB download unnecessary. The
fetch still verifies it, so a manifest that lied would fail the build instead of installing
something else. The URL carries an opaque build id (`/<version>-<build id>/linux-x64/…`) that only
the manifest knows, and storing the url whole is what keeps it from being a field of its own.

## Shared conventions

- The repo path comes as an ARGUMENT, never a literal in the script (rule 11).
- `nix` does NOT go into `runtimeInputs`: they use the system's, so as not to drag a second Nix
  into the store with a version possibly diverging from the daemon's.
- They leave the repo DIRTY on purpose. The commit is the user's and atomic, one per package
  (`chore(<name>): <old> -> <new>`), which is what each bump prints.
- A round trip is the test: set `source.json` to an older version and a fake hash, run the bump, and
  the file must come back byte-identical to the committed one. All four passed it on 26/09/2026.

## nxBender's three patches

Not a bump script, but the same "vendored upstream that needs fixing" family, and
[`pkgs/nxbender/package.nix`](../../../pkgs/nxbender/package.nix) points here.

1. **`ssl.wrap_socket` was REMOVED in Python 3.12+**, so the tunnel broke with an
   `AttributeError`. Swapped for the modern API with an unverified context (CERT_NONE), which is
   `wrap_socket`'s original no-args behavior. nxBender validates the server through its own
   fingerprint, not through the certificate chain, so nothing is lost.
2. **pppd 2.5+ has no `nomp` option** (which turned multilink off), so it answers
   `unrecognized option`. Multilink already comes OFF by default on a single link, so the option
   was redundant.
3. **Split tunnel.** FAI pushes a default route (`0.0.0.0/0`) that would throw ALL of the internet
   through the tunnel. The patch filters the `/0` out of `setup_routes`, so only FAI's internal
   subnets go through the VPN and the rest keeps going over the LAN. On teardown `ppp0` goes down
   and the kernel cleans up.
