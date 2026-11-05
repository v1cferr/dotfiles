# nix-cache

Modules: [`modules/nixos/core/nix-cache/default.nix`](../../../modules/nixos/core/nix-cache/default.nix),
[`.github/workflows/cache.yml`](../../../.github/workflows/cache.yml),
[`tools/ci/cache-push.sh`](../../../tools/ci/cache-push.sh)

A private binary cache on Cloudflare R2, filled every night by CI, so an `upgrade` at home
downloads what this config compiles instead of compiling it.

## Why it exists

cache.nixos.org only holds packages exactly as nixpkgs defines them. Every override, patch,
vendored package or git input here is a derivation Hydra never built, so it compiled on this
machine, and again on every nixpkgs bump, since a new dependency is a new hash. On 05/11/2026 that
was papers (~28 min), vicinae (~20 min), win11-icon-theme (~5 min), openrgb, quickshell and
caddy: close to an hour per `upgrade`, on a 15 GiB machine that went 20 GiB into swap doing it.
Dropping the papers override and capping the build parallelism
([core](core.md#build-parallelism-is-capped-by-memory-not-cores)) cut that down; this removes it.

## What the nightly run does

[`cache.yml`](../../../.github/workflows/cache.yml), daily at 05:37 UTC:

1. The vendored bumps, then `nix flake update` on every input EXCEPT `duo-streak-daemon`. That one
   is private, CI reads it through the empty stub like the gate does, and its lock entry is
   updated at home by `update`.
2. `nix flake check`, the same gate as [`nix.yml`](../../../.github/workflows/nix.yml).
3. [`cache-push.sh`](../../../tools/ci/cache-push.sh) asks a dry run of the host's toplevel what
   no substituter has, keeps only the derivations a cache would ever serve, builds them and
   pushes the outputs, signed.
4. Only when all of that passed: one commit per bumped package plus one for the lock, straight
   to `main`.

**Only what a cache would serve.** The whole system is 41 GiB, past the runner's disk. Trivial
builders (units, `writeText`, `buildEnv`, wrappers) set `allowSubstitutes = false`, so no cache
is ever asked for them and they rebuild at home in seconds; the script drops them. jq's `//`
reads `false` as missing, which is why the filter asks `has("allowSubstitutes")` explicitly.

**`nix copy --no-recursive`.** A pushed path's references are either on cache.nixos.org or in the
same pushed list, so copying closures would only re-upload nixpkgs into a 10 GB free tier.

**The stub does not change the hashes that matter.** Only derivations that read the private
input differ between CI and home, and none of the compiled ones do.

## Private, with a read-only key at home

The bucket is private on purpose: many pushed packages are unfree (VS Code, Codex, ChatGPT,
CurseForge, Steam's FHS root), and a public cache would redistribute them. Two R2 tokens, scoped
to the bucket:

| Token | Lives in | Used by |
| --- | --- | --- |
| Object Read & Write | GitHub secrets `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` | the nightly push |
| Object Read | Bitwarden "Nix Cache R2 Read", synced to sops | the nix-daemon at home |

The signing key's private half is the GitHub secret `NIX_CACHE_SIGNING_KEY`, backed up in
Bitwarden as "Nix Cache Signing Key"; the public half is
[`nix-cache.pub`](../../../modules/nixos/core/nix-cache), in git. The daemon gets the read key
through an `EnvironmentFile` rendered by sops, so it never reaches the store.

The substituter sits at priority 45, after cache.nixos.org's 40: the official cache still
answers everything it has.

## Setting it up, once

```sh
export BW_SESSION=$(bw unlock --raw)
nix-cache-setup ~/Projects/GitHub/v1cferr/dotfiles
```

[`nix-cache-setup`](../../../modules/nixos/core/nix-cache/scripts/setup.sh) does everything:

1. Generates the signing key: `nix-cache.pub` into git, the private half into the GitHub secret and
   Bitwarden ("Nix Cache Signing Key").
2. MINTS the two R2 tokens through the API, each scoped to the one bucket. R2 needs no separate
   S3 key: a token's `id` is the Access Key ID and the SHA-256 of its value is the Secret. The
   read-write pair goes to GitHub, the read-only pair to Bitwarden ("Nix Cache R2 Read").
3. Runs `sync-secrets` and stages the `.pub`, the index and `secrets.yaml`.

Creating tokens needs a token allowed to create tokens, and that one has to come from the
dashboard: the first run asks for it once (My Profile, API Tokens, template "Create Additional
Tokens") and keeps it in Bitwarden as "Cloudflare API Token Creator", so a rotation reads it from
there. Every value travels through stdin, the environment or a `/dev/fd` header, never argv, where
`ps` would show it. Each step skips what already exists: replacing a key is a decision, not a
rerun. After it: commit, `rebuild`, then run the workflow once by hand from the Actions tab.

The module stays inert until both the `.pub` and the synced read key exist.

## No expiry, for now

R2 lifecycle rules only expire by upload AGE. That would delete `nix-cache-info` and narinfos still
in use, and with `fallback = false` a missing NAR is an error, not a local build. So nothing
expires yet: past the free 10 GB, R2 costs ~US$ 0.015 per GB per month. Pruning belongs to a
generation-aware script, not to the bucket.
