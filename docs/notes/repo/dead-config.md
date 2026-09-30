# dead-config: what is declared and never used

`pkgs/dead-config.nix`, wired into `checks` and into the pre-commit hooks. Run it by hand with
`nix run .#dead-config`.

Rule 16 says dead config leaves the repo. Until this existed, the only thing enforcing that was me
remembering, which is the same "intention, not a standard" the CI's own header rejects.

## The seven checks

| Check | What is dead | Why it is silent |
| --- | --- | --- |
| module | a `.nix` under `system/` or `home/` that no `imports` reaches | it evaluates to nothing, so nothing fails; the file just sits there looking live |
| input | a flake input nothing consumes | it is still fetched, locked and evaluated on every build |
| option | a `my.*` option nobody reads through `config`/`osConfig` | an SSOT with no consumer, which is the thing rule 11 exists to prevent |
| note | a page in `docs/notes/` no module points at | rule 2 made the pointer the ONLY path in, so an unpointed page is unreachable |
| secret | a key in `secrets.yaml` nothing consumes | a credential kept, re-encrypted for two recipients and rotated for nobody |
| secret-index | a key in `bitwarden-secrets.json` with no value in the vault | it breaks at `nixos-rebuild`, which is a far slower loop than a hook |
| artifact | a tracked build output or editor dropping | a `.gitignore` only stops what is not tracked YET |

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

### The artifact check exists because .gitignore is not retroactive

`scripts/__pycache__/router-sync.cpython-313.pyc` was tracked for months. `.gitignore` had no rule
for python bytecode, and by the time one was added the file was already in the index, where the
ignore file has no effect. Nothing surfaced it, because a `.pyc` breaks nothing: it is simply
regenerated and never read.

That is the whole shape of the problem this tool exists for. The rule and the check are two
different guarantees: the rule stops the NEXT one, the check finds the one already in.

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
  Both `./x` and `../x` resolve, so a host importing a shared module by a relative path counts as
  a reach; before 30/09/2026 a `../` was resolved one level too shallow and read as unreached.
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

### Every exception has a review date (rule 22, 29/09/2026)

Each entry is `(reason, "YYYY-MM-DD")`. A reason alone explains why an exception exists TODAY, and
says nothing about whether it still does in 2029; without a date the list only grows, because
nobody deletes a line that looks deliberate. The date is not a deadline for the THING, it is the day
the question comes back: on it, the exception is deleted or the date moves in a commit that says
why, which is the same contract as a budget in `ci/eval-budget.json`.

| Exception | Review by | Why that date |
| --- | --- | --- |
| `secret:restic_password` | 2026-12-31 | new storage was the plan; a quarter is when to ask again |
| `note:docs/notes/repo/license.md` | 2027-09-29 | a policy, so a yearly look is enough |

**`--expired` also reads `.gitleaks.toml`**: the `# review-by:` line above each allowlist block,
keyed by its `description` ([github-settings](github-settings.md)). One clock for every exception
list in the repo, instead of one per tool.

**The date check is `dead-config --expired`, and it runs in the CANARY, never in the gate.** The
gate is hermetic and its result is cached by input: a date would make the same commit pass on
Monday and fail on Tuesday, and a cached green would hide the Tuesday anyway. "The answer changes
with no commit of mine" is the canary's definition ([flake.md](flake.md)), so the job lives there
and a red run reaches the phone through the ntfy job. MEASURED: with the restic date moved to
2026-01-01 by hand, `--expired` printed the entry and exited 1; reverted, it exits 0.

## The long form of rule 16

Moved here VERBATIM from [rules.md](../../rules.md) on 30/09/2026, when rule 16 became a
card. Nothing was cut; the card links back here.

DEAD CONFIG GOES OUT IN THE SAME COMMIT THAT REMOVED ITS USE, and DRIFT IS A BUG, not tidying for later. There are three forms, and all three LIE instead of failing: **dead** (a declaration nobody reads), **orphan** (the use went away, the declaration stayed) and **drift** (the text describes a system that no longer exists). Rule 14 governs WHO WRITES an artifact; this one governs whether it is still ALIVE and TRUE. The cost never shows up on the day it is born: it is charged to the next reader, who has no way to tell "this is necessary" from "this is leftover", and when in doubt they preserve it, so the junk becomes permanent. HOW TO DETECT IT: `grep -rn '<name>' --include='*.nix' .`, and if only the declaration shows up, it is dead. THAT GREP IS NOT ENOUGH, and getting this wrong is WORSE than not auditing: a declaration can be GENERATED from DATA, and then the name does not exist in any `.nix`. That is what caught me on 11/08/2026: I called `caddy_pos_hash_v1cferr`/`_jp` orphans because the grep over `.nix` returned zero, and they were declared the whole time through `secrets/bitwarden-secrets.json`, which `system/core/secrets.nix` walks with `mapAttrs`. Deleting them from the vault alone created "declared and absent", which `validateSopsFiles` fails at BUILD time (and `sync-secrets` would bring them back from Bitwarden on the next run). DERIVED RULE: always audit for orphans by reconciling the two RESOLVED ends, `config.sops.secrets` (declared, with the generators already applied) against the names in `secrets.yaml`, never by a text `grep`. It holds for every index-to-generator pair: what declares can be JSON, not Nix. And dead config BITES, it does not just clutter: the `requiredSecrets` in caddy.nix was a literal, so a password nobody read anymore was enough to leave Caddy inert on the switch, taking jellyfin, torrent, ai and duo down with it. Other real cases: `xembedsniproxy` cited in 3 comments without EVER having been installed; `tray-native-menu.sh` pointing at the path of a waybar that was already removed; a `.env` at the root with a Tailscale auth key that nothing read. FOR WHAT IS NOT DECLARED (rule 6, an app that rewrites itself) the antidote is not to declare it, it is to give git VISIBILITY: a mirror regenerated by a COMMAND and never by hand (`vscode-extensions-dump` producing `extensions.txt`), or a direct write into the repo through `mkOutOfStoreSymlink` (`settings.json`/`keybindings.json`, the same link as `hyprland.lua`). What git can see does not drift silently. DO NOT CONFUSE THIS with erasing history: a comment explaining why something is the way it is TODAY by citing what died ("replaces `trustedInterfaces = [ tailscale0 ]`") is rule 2 working, not drift. What dies is the executable DECLARATION, not the memory of why it existed.
