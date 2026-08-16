# dead-config: what is declared and never used

`pkgs/dead-config.nix`, wired into `checks` and into the pre-commit hooks. Run it by hand with
`nix run .#dead-config`.

Rule 16 says dead config leaves the repo. Until this existed, the only thing enforcing that was me
remembering, which is the same "intention, not a standard" the CI's own header rejects.

## The five checks

| Check | What is dead | Why it is silent |
| --- | --- | --- |
| module | a `.nix` under `system/` or `home/` that no `imports` reaches | it evaluates to nothing, so nothing fails; the file just sits there looking live |
| input | a flake input nothing consumes | it is still fetched, locked and evaluated on every build |
| option | a `my.*` option nobody reads through `config`/`osConfig` | an SSOT with no consumer, which is the thing rule 11 exists to prevent |
| note | a page in `docs/notes/` no module points at | rule 2 made the pointer the ONLY path in, so an unpointed page is unreachable |
| secret | a key in `secrets.yaml` nothing consumes | a credential kept, re-encrypted for two recipients and rotated for nobody |

## What it found on the first run

**`jellyfin_api_key`**: in `secrets.yaml`, consumed by nothing. It belongs to the OLD Jellyfin
server and answers 401, so it was not merely unused, it was unusable. REMOVED on 16/08/2026, and
`ALLOWED` is empty again, which is where it should stay.

Everything else came back clean, so the other four checks are REGRESSION GUARDS rather than
bug-finders. That is the honest description of them.

### Removing a secret takes THREE deletions, not one

The first attempt deleted only the key from `secrets.yaml` and broke the build:

```text
sops-install-secrets: manifest is not valid: secret jellyfin_api_key in
/nix/store/…-secrets.yaml is not valid: the key 'jellyfin_api_key' cannot be found
```

The vault is the VALUE; the DECLARATION lives elsewhere, in two places at once:

1. `secrets/secrets.yaml`, the encrypted value.
2. `secrets/bitwarden-secrets.json`, the index, which `system/core/secrets.nix` turns into one
   `sops.secrets.<name>` per entry through `lib.mapAttrs`.
3. `system/core/secrets.nix` itself, when the secret also has a hand-written override (this one
   had `owner`/`mode`, so it was declared twice over).

Delete from the yaml alone and sops-nix still declares the secret, then fails at BUILD time
because the key it was told to install is gone. That is a loud failure, which is the good case;
the reverse (an entry in the index with no value in the vault) is the same error from the other
side.

This is also why `dead-config` reports a secret as dead from the CONSUMPTION side and not the
declaration side: a declaration is not a use, and here there were two declarations and zero uses.

## The naive version of each check is wrong, and that matters

A lint you learn to ignore is worse than a lint turned off, which is the same argument
[`flake.md`](flake.md) records for the two statix rules that are disabled. Every check here was
prototyped, produced a false positive, and was fixed before being written down:

- **inputs**: grepping for `inputs.<name>` misses `nixpkgs-unstable`, which is destructured as a
  bare argument of `outputs` and used as `import nixpkgs-unstable`. The check subtracts the
  declaration block and then looks for the name ANYWHERE, which catches both forms. It also has to
  scan the whole tree and not just `flake.nix`, because `zen-browser` is consumed in
  `home/packages.nix` through `specialArgs`.
- **options**: "declared and used at most once" flagged four live options
  (`my.fai.workstation`, `my.disk`, `my.net.domain`, `my.ingress`), because a consumer reads a
  CHILD (`config.my.ingress.<svc>`) or reads it several times in one file. The check looks for a
  read through `config.` or `osConfig.` specifically.
- **modules**: resolving every `./path` in the file flags nothing, but it also PROVES nothing,
  since it counts a path mentioned in a comment. The check parses `imports = [ … ]` blocks and
  walks reachability from the real roots (`system/default.nix`, `home/default.nix`, `hosts/*`).
  `pkgs/` is deliberately exempt: it is reached by `callPackage` in `flake.nix`, not by an
  `imports` list.

## Two checks that were considered and REJECTED

**A secret consumed but NOT provisioned.** It sounds like the more valuable direction, and it
produces a false positive immediately: `home/shell/ntfy.nix` reads `/run/secrets/ntfy_topic`, which
does not exist, and that is BY DESIGN. The script tests `[ ! -r "$secret" ]`, warns and exits 0,
because "the caller must not break because the warning did not go out". A check that cannot tell a
guarded read from an unguarded one would flag good code.

**Input age from `flake.lock`.** `lastModified` is the UPSTREAM commit date, not the date we last
fetched. `disko` reads as 66 days old only because disko has not had a commit in 66 days, and
`nix flake update` already ran. Measuring "our" staleness would mean measuring the lock file's own
git mtime, which is a different and much weaker signal. See [`flake.md`](flake.md) for why the
DeterminateSystems flake-checker was rejected for the same reason plus a vendor one.

## The ALLOWED list

A tracked exception needs a REASON string, so it appears in the diff instead of rotting in silence.
Emptying that list is the goal, not growing it. If a finding is real, the fix is deleting the thing,
not adding a line.
