# vscode-bump, curseforge-bump and codex-bump

Modules: [`pkgs/vscode-bump.nix`](../../../pkgs/vscode-bump.nix),
[`pkgs/curseforge-bump.nix`](../../../pkgs/curseforge-bump.nix),
[`pkgs/codex-bump.nix`](../../../pkgs/codex-bump.nix)

Three scripts that keep a vendored binary on its latest version without anybody editing a hash by
hand. They share a reason and differ in how they ask "did it change?", so they live on one page.

## The structural reason all three exist

Rule 13 pins the dependency universe: no fetch without a hash, no implicit "latest". That rule has
a consequence people miss: **a src with a locked hash never updates itself.** What exists is not
an "input that follows upstream", it is an AUTOMATED BUMP.

All three run from the `update`/`upgrade` alias
([`home/shell/zsh.nix`](../../../home/shell/zsh.nix)), before `nix flake update`, so "always on
the latest" happens at rebuild time. All three are a NO-OP when already current, because they run
on every `upgrade`.

## Where they differ

| | vscode-bump | curseforge-bump | codex-bump |
| --- | --- | --- | --- |
| Upstream URL | versioned (`/1.133.0/linux-x64/stable`) | a POINTER (`curseforge-latest-linux.AppImage`) | versioned (`/rust-v0.148.0/…musl.tar.gz`) |
| What the bump changes | only the version number | version **and** the recomputed hash | version **and** the recomputed hash |
| How it learns the version | the official update API, `productVersion` | the `control` file of the `.deb` of the same release | the redirect of `/releases/latest` |

**VS Code.** The input URL is versioned on purpose. `/latest/` is a pointer, so on every release
the pinned narHash stops matching and the flake no longer evaluates on a clean machine. That
broke the CI on 05/08/2026:

```text
error: mismatch in field 'narHash' of input '.../latest/linux-x64/stable'
       lock: sha256-2Fzf... | served: sha256-PLpT...
```

It passed locally only because the old tarball was already in the store. Measured before
switching: `/1.131.0/` returns exactly the `sha256-2Fzf...` that was in the lock and `/1.132.0/`
returns `sha256-PLpT...`, both stable across repeated fetches. A versioned artifact is immutable;
a pointer is not.

The script reads `productVersion` and NOT `version` from the API, because the second one is the
commit hash (`df53daa…`), not the `1.133.0` that goes in the URL.

**CurseForge.** Overwolf publishes no versioned URL, so the hash is the only anchor and it has to
be RECOMPUTED, not just swapped. Downloading 139 MiB on every `update` to find out nothing changed
would be absurd, and there is no version API, so what answers "did it change?" is a **256 KiB
range request on the `.deb`**: the `control` file sits in the first few KiB and carries the
version. The AppImage is only downloaded when the answer is yes.

Measured on 14/08/2026: both artifacts are published at the same instant and carry the same
release (`1.316.0~37372-37372` in the `.deb`, `1.316.0-37372.37372` in `X-AppImage-Version`); the
strings differ only in formatting, hence the normalization in the script. If they ever get out of
sync, the worst case is downloading the AppImage for nothing, since the script compares and
rewrites, it does not break.

One shell trap in there: the control member goes through a FILE and not a pipe, because GNU tar
only autodetects the compression when it can seek, so `ar p … | tar -xO` dies with
`Archive is compressed. Use -J option`. From a file it works it out on its own, which also lets
the script survive the day Overwolf swaps `.xz` for `.zst`.

**Codex.** A GitHub release is the easy case of both halves: the asset URL is versioned, so it is
immutable like VS Code's, and the question "did it change?" costs ONE HEAD request, because
`/releases/latest` REDIRECTS to the tag:

```text
https://github.com/openai/codex/releases/latest
  -> https://github.com/openai/codex/releases/tag/rust-v0.148.0
```

The REST API would answer the same thing and spend one of the 60 anonymous calls per hour, and it
would drag `jq` in to read the JSON. The redirect needs neither. Only when the tag differs does
the script pull the 93 MiB tarball to compute the hash.

The tag carries a `rust-v` prefix because that repo releases more than one artifact line, so the
version is `''${tag##*/rust-v}`. When a tag does NOT match that shape the stripping is a no-op and
the whole URL stays in the variable, which is what the plausibility `case` catches: slashes and
letters are not a version. Prereleases never reach it, since `/releases/latest` skips them, and
`0.149.0-alpha.2` existed the day this was written.

## Shared conventions

- The repo path comes as an ARGUMENT, never a literal in the script (rule 11).
- `nix` does NOT go into `runtimeInputs`: they use the system's, so as not to drag a second Nix
  into the store with a version possibly diverging from the daemon's.
- They leave the repo DIRTY on purpose. The commit is the user's, atomic, and the lock goes in the
  same commit as the change that required it (rule 13).

## nxBender's three patches

Not a bump script, but the same "vendored upstream that needs fixing" family, and
[`pkgs/nxbender.nix`](../../../pkgs/nxbender.nix) points here.

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
