# The flake: inputs, overlays and the quality gate

`flake.nix`. Everything here is a decision that cost something to reach, which is why it is written
down rather than left to be re-derived.

The version strategy these inputs implement (stable base, unstable per package, upstream directly)
is in [`version-bumps.md`](version-bumps.md).

## The inputs

### zen-browser, and the `follows` hazard

Zen is NOT in nixpkgs, so this flake follows the upstream releases. "Always the latest version"
means bumping with `nix flake update zen-browser`.

**IT FOLLOWS THE UNSTABLE BASE, and that is the only `follows` in the file pointing there.** It said
`follows = "nixpkgs"` (stable) until 15/08/2026, when a `nix flake update` broke the eval outright:

```text
lib.customisation.callPackageWith: Function called without required argument "ffmpeg_9",
did you mean "ffmpeg_4", "ffmpeg_6" or "ffmpeg_7"?
```

Upstream started asking for `ffmpeg_9` in its `package.nix`, and 26.05 stops at `ffmpeg_7`.

**That is the `follows` hazard**: forcing somebody else's flake onto MY pin works right up to the
day they use an attribute that only exists in a newer nixpkgs, and then it fails at EVAL, with a
message that names a package I never wrote.

`nixpkgs-unstable` and not "drop the follows": zen's own lock pins nixpkgs at the exact commit our
unstable input is already at (0e251e24, checked, not assumed), so this keeps the dedup the line
existed for, adds ZERO inputs to the lock, and stops fighting what upstream already expects.
Dropping the follows would pull a THIRD nixpkgs into the closure.

home-manager keeps following ours, because only `packages.<system>.default` is consumed here, never
the hm-module, so that side never gets evaluated.

### The rest, in one line each

| Input | Why it exists |
| --- | --- |
| `duo-streak-daemon` | the app lives in ITS OWN repo; here it is only DEPLOY, the commit pinned in the lock and compose building from the store path. `flake = false`, since it is a plain code repo with no Nix outputs. It is PRIVATE, so `git+ssh`: it reuses the SSH key with no token in sops, `nix flake update` runs as the USER who has the key, and the rebuild as root reuses the already-pinned store path with no re-fetch |
| `minegrub-world-sel-theme` | a GRUB theme where each OS/generation becomes a Minecraft "world" with an icon and a description. The other theme by the same author (`minegrub-theme`, the main menu) was passed over: an entry becomes a button, with no icon per OS |
| `quickshell` | a shell/bar in QML (outfoxxed), NOT in nixpkgs. See [`quickshell.md`](../desktop/quickshell.md) |
| `browser-previews` | nixpkgs only packages Chrome stable; this maintained nix-community flake keeps `google-chrome-dev` fresh |
| `git-hooks.nix` | pre-commit managed by Nix, so the lint catches things BEFORE the commit instead of after the push. `cachix/git-hooks.nix` is the current name; the old `pre-commit-hooks.nix` repo redirects |

### claude-desktop

NOT in nixpkgs (issue #366213 was closed; the channel only has claude-code and claude-monitor).
This flake REPACKAGES the OFFICIAL `.deb` Anthropic started publishing on 30/06/2026 (the Linux
beta, its own APT), which is the nixpkgs pattern for a vendored binary (`dpkg-deb` plus
`autoPatchelfHook`), like discord and vscode.

Passed over: `k3d3/claude-desktop-linux-flake`, the pioneer, but it reverse engineered the WINDOWS
binary and has been idle since nov/2025; and `heytcass/claude-for-linux`, which extracts from the
macOS DMG and has 6 stars against 77 issues. Upstream CI bumps version and hash on its own, so "the
latest version" is `nix flake update claude-desktop`.

### vscode-tarball, and why the URL is versioned

VS Code from the OFFICIAL stable-channel tarball, at a FIXED version. It exists because nixpkgs
does not serve: the bump there is human or bot and runs 3 to 14 days behind, and it sometimes SKIPS
a release (1.125 to 1.127, 1.127 to 1.129.1 in jul/26). The cause is structural: the VS Code
auto-updater does not run with a read-only store, so the version is literally whatever is in the
lock. This is NOT Insiders.

**The name**: it was `vscode-latest` until 05/08/2026, and the name turned into a lie the minute the
URL was pinned, since "latest" promised an automatic tracking that no longer exists. `-tarball` says
what it IS, and explains the `flake = false`, without promising a version.

**A VERSIONED URL and not `/latest/`**, changed on 05/08/2026 because the CI went RED:

```text
error: mismatch in field 'narHash' of input '.../latest/linux-x64/stable'
       lock: sha256-2Fzf... | served: sha256-PLpT...
```

`/latest/` is a POINTER. 1.132.0 shipped, the pointer moved, and the pinned narHash (1.131.0's)
stopped matching. Here it passed because the old tarball was already in the store; on a clean
machine (CI, a fresh clone, a reinstall) the flake did not evaluate anymore. **The hole in rule 13
was not a 2032 risk, it broke on every VS Code release.**

Measured before switching, which is what proves the fix: `/1.131.0/` returns exactly the
`sha256-2Fzf...` that was in the lock and `/1.132.0/` returns `sha256-PLpT...`, both stable across
repeated fetches. A versioned artifact is immutable; a pointer is not.

**The price** of a fixed URL is that `nix flake update` does not bring a new version on its own. Who
pays it is `vscode-bump` since 06/08/2026: it queries the official API, rewrites the number on that
line and runs `nix flake update vscode-tarball`. It is the first step of the `update`/`upgrade`
aliases, so "always on the latest stable" happens at rebuild time, with no manual edit and without
breaking rule 13, since the hash is still pinned in the lock. What changed is WHO updates it.
Bumping by hand still works: edit the line plus `nix flake update vscode-tarball`.

## The unstable instance, and why it is hoisted

ONE instance of the unstable channel, created OUTSIDE the overlay on purpose.

Inside it, the `import` runs once per `pkgs` instance, and an overlay also applies to the SPLICES
(`pkgsi686Linux`, which Steam instantiates because of 32-bit): the day someone touches
`pkgs.pkgsi686Linux.unstable`, the unstable tree would be imported ANOTHER time. Today it is lazy
and costs nothing, and hoisting the import is what keeps it that way. It is also what the community
associates with evaluation OOM (discourse 1517): the cost shows up once the instances add up.

`overlayUnstable` then exposes `pkgs.unstable.<package>` while the whole rest of the system stays on
the stable base. That is what gives the choice per package.

## The three package overlays

### Spotify's `--no-zygote`

Without it the app does not open: its CEF aborts with "GPU process isn't usable. Goodbye." and dies
of SIGTRAP in ~270 ms, with no window and no visible error. `--disable-gpu` and `--no-sandbox`
change nothing; only this flag works around it. Measured 11/08/2026 on 1.2.92.147, and the earlier
suspicion that it was the VERSION was wrong: 1.2.92 crashes just like 1.2.90.

**WHY IN THE PACKAGE** and not in `autostart.nix`'s `exec`, which would be the shorter line:
Spotify's `.desktop` uses `Exec=spotify`, a BARE name resolved through PATH. A flag only in the
autostart would fix boot and leave the MENU crashing, with two places to keep in sync. Wrapping the
package means every path that reaches the profile's `spotify` gets the flag. Rule 15, a single
owner.

`postFixup` and not `postInstall`, because the nixpkgs recipe does its own wrap in `installPhase`
and `fixupPhase` runs AFTER, so wrapping earlier would wrap what does not exist yet.
`$out/bin/spotify` is a symlink to `../share/spotify/spotify`; `wrapProgram` moves the symlink to
`bin/.spotify-wrapped` (the relative target stays valid, same dir) and puts the wrapper in its
place.

It patches INSIDE `unstable`, hence after `overlayUnstable`, for the same reason as the vscode
overlay: `unstable` is another import of nixpkgs.

**REMOVE once Spotify opens again without the flag.** Testing that is running `spotify` without it.

### vscode: the tarball SRC over the unstable RECIPE

It swaps only the `src`, keeping the RECIPE from unstable. The nixpkgs `generic.nix` has
version-gated logic (`versionAtLeast vscodeVersion "1.129.0"`), so patching a fresh recipe is the
minimal delta; over the 26.05 recipe (which was 1.119) a 12-version jump would go through branches
that do not exist.

Two details: `version` is read from the `package.json` of the tarball itself, and since the input is
already a store path at eval time that is a plain `readFile`, so no IFD and no second hash to
maintain. And `sourceRoot` is set because the flake tarball fetcher STRIPS the top-level dir
(`VSCode-linux-x64`), unlike the nixpkgs `fetchurl`, which uses `sourceRoot = ""`.

### btop with Intel Xe support: TEMPORARY, with an expiry date

btop 1.4.7 (the one in nixpkgs) ALREADY ships `-DBTOP_GPU=ON`. The gap is neither a build flag nor a
root permission: its Intel backend is i915 and ONLY i915. The Arc B580 is Battlemage, runs on `xe`,
and i915 does not even support that chip. Measured on the 1.4.7 binary: only `i915` and
`intel_i915_info` exist, no reference to `xe`. So `sudo btop` would show nothing either, because
there is no code to read the counter. Upstream issues #1407 (the Xe feature request) and #1073
(this card) are both OPEN.

PR #1457 implements Xe (util through fdinfo with a gtidle/PMU fallback, clock through sysfs,
dedicated VRAM, power through hwmon) and was tested on a B580. Here it runs WITHOUT root.

**Why the whole fork and not `patches = [ (fetchpatch ...) ]`**, which would be the smaller delta:
the PR is against `main`, and the diff does NOT apply on top of tag v1.4.7 (`git apply --check`
fails at `src/linux/btop_collect.cpp:317`). Swapping the `src` is the same pattern as the vscode
overlay: the nixpkgs recipe, code from somewhere else.

**REMOVE once #1457 merges and the release carrying it reaches the channel**: delete this overlay,
its line in the overlay list and the `btop` in `packages.${system}`. Then `pkgs.btop` goes back to
being the nixpkgs one, Xe included. Rule 16: zero legacy, this must not become furniture.

The `version` follows the nixpkgs convention for an unreleased snapshot
(`-unstable-<commit date>`), because the fork's CMakeLists still says 1.4.7 and calling it plain
"1.4.7" would hide that it is not the release. Since the binary reports 1.4.7 and not that string,
`versionCheckHook` would fail it, hence `doInstallCheck = false`. `changelog` is overridden because
the nixpkgs one is interpolated with the version and would point at a tag that does not exist.

### claude-desktop's keyring

Electron autodetects the secret backend from `XDG_CURRENT_DESKTOP`, "Hyprland" matches no case in
Chromium's os_crypt, it falls back to "basic text", and `safeStorage` then declares itself
unavailable, so the app warns "your sign-in won't be saved" and asks for a login EVERY time.

The SAME bug and the SAME remedy as VS Code, but without `commandLineArgs`, since this is not the
nixpkgs electron, hence a wrapper. Only `claude-desktop` is wrapped: the upstream overlay builds the
`-fhs` variant on top of `final.claude-desktop`, which is the FIXPOINT one, so the FHS variant
inherits this wrap by itself. That is also why `overlayClaudeKeyring` comes AFTER the upstream
overlay in the list: it re-wraps their package.

## Hosts

A host is the COMMON modules (overlay, sops, disko, `./system`, home-manager) plus the host's own
FOLDER. A new host means creating `hosts/<host>/` (`default.nix`, `disko.nix`, `services.nix`) and
adding one line to `nixosConfigurations`. home-manager comes in as a module, so one rebuild applies
system and user together.

What belongs to the HOST and not to `./system`: hostname, disks, kernel, monitors, stateVersion and
the `my.services` panel. `system/` declares the options; the host answers them.

`nixos-kingston` is the ONLY host: an NVMe Kingston KC3000 on an ASUS EX-B560M-V5, btrfs with
subvolumes ready for impermanence, declarative disk through disko.

**`hostPlatform` instead of nixosSystem's `system` argument.** nixpkgs itself calls that one a
"legacy" output and zeroes it in the flake wrapper: «Allow system to be set modularly in
nixpkgs.system. We set it to null, to remove the "legacy" entrypoint's non-hermetic default.» Its
default is `builtins.currentSystem`, which is IMPURE; declaring it as a module option is the
hermetic way, and a cross-compiled host would only override it there.

## `packages.<system>`

What THIS repo packages or re-wraps, exposed piece by piece, so `nix build .#nxbender` works. They
used to exist only inside the overlay, which made them unbuildable in isolation: there was no way to
test a patch without going through a whole rebuild.

`pkgs` comes from the HOST ITSELF and not from a fresh `import nixpkgs`, for two reasons: it is the
SAME object the system installs, so the check below cannot diverge from what the machine receives
(rule 14), and it does not add a second nixpkgs instantiation to the evaluation.

## `nix fmt`

Without this output, nixfmt would exist ONLY inside VS Code (through nixd/nix-ide), and "the repo
style" would depend on which editor someone opened. Declaring it makes the standard verifiable from
outside the editor, which is what a CI uses. nixfmt is the OFFICIAL formatter since RFC 166, the
same one nixpkgs adopted, so this is aligning with upstream, not picking a taste.

**`nixfmt-tree` and NOT bare `nixfmt`**, and both reasons came from a real mistake (03/08):

1. `nix fmt` with no path passes no argument, and bare nixfmt falls back to the STDIN invocation
   (the deprecated one) with an empty stdin, so "unexpected end of input".
2. `nix fmt .` makes bare nixfmt walk the WHOLE tree, including the `./result` symlink of a
   `nixos-rebuild build`. It walked into `/nix/store` and died with
   `openTempFileWithDefaultPermissions: permission denied (Read-only file system)` trying to format
   a `.nix` inside bitwarden's `node_modules`.

The wrapper (treefmt) fixes both: it works with no argument and respects the `.gitignore`, so it
never leaves what is versioned. nixfmt's own warning recommends exactly it.

## The quality gate: ONE definition, THREE consumers

Both `nix flake check` and the pre-commit hook are born from `checks`. They used to be three
hand-made derivations linting exactly what the hooks were going to lint: two definitions of the same
rule, which is the recipe for rule 14's silent drift, where the gate passes, the hook fails, and
nobody understands why. git-hooks.nix collapses the two.

The CI (`.github/workflows/nix.yml`) became the THIRD consumer on 04/08/2026: it runs
`nix flake check` with `--override-input duo-streak-daemon path:./ci/stub-duo`, the stub avoiding
the need for a deploy key for the private input. So touching the hooks changes the CI by itself;
there is no second list of linters in the workflow.

**`nixfmt-rfc-style` and NOT `nixfmt`**: in this hook set the name `nixfmt` still points at the
classic one, and asking for the wrong one would reformat the repo in the old style. As of
04/08/2026 `nix flake check` already WARNS "nixfmt-rfc-style is now the same as pkgs.nixfmt which
should be used instead", so the distinction is expiring in nixpkgs. Once the git-hooks.nix hook set
follows, the right name goes back to being `nixfmt`; until then, switching would reformat in the old
style.

**The shellcheck hook covers `./scripts`.** Rule 7 says the logic lives in the build, and
`sync-secrets.sh` already gets shellcheck for free by coming from a `writeShellApplication`.
`owfetch.sh` does NOT, because it runs in ash on OpenWrt, not here, so no derivation wraps it.
Without this hook, the only `.sh` in the repo that runs on SOMEONE ELSE'S machine would be the only
one with no verification.

### `checks.packages`: building what the gate did not cover (04/08/2026)

`nix flake check` builds what is in `checks` («the derivations specified by the flake's checks output
can be built successfully»), but of `nixosConfigurations` it only requires that the toplevel «must be
derivations»: it EVALUATES the host and stops there. Measured before this line, the check printed
"running 1 flake checks..." and the only thing built was pre-commit.

The difference matters because what is fragile here is not evaluation, it is PACKAGING: nxbender's
3 patches, vscode's `sourceRoot` and the `wrapProgram` over claude-desktop's `.deb` are assumptions
about someone else's tree. None of them breaks at eval, they break at BUILD, AFTER a
`nix flake update`. And `upgrade` is `update && nh os switch`, so the breakage landed in the middle
of the switch.

`linkFarm` and not `symlinkJoin`: a farm does not merge directories, so two packages with the same
`bin/` do not collide. The derivation is disposable; the value is the build.

**DELIBERATELY not `system.build.toplevel`**: building the whole system on the GitHub runner would
drag in quickshell (Qt/C++). Only the packages this repo controls come in, which is where the
patches can rot.

**`curseforge` stays OUT, and it is the only exception**: its src is a POINTER URL
(`curseforge-latest-linux.AppImage`, since Overwolf publishes no versioned URL), so on every release
of theirs the pinned hash stops matching and the check would go RED for something that is not in
this repo. Same pain as VS Code's `/latest/`, except there is no fixed URL to pick: the remedy is
`curseforge-bump`, which runs on `update` and DOES enter the check, because its shellcheck is
stable. Testing the packaging is `nix build .#curseforge`, by hand.

## The devShell

It exists for a CONCRETE reason, not for completeness: entering it is what INSTALLS the hook into
`.git/hooks/pre-commit`, through git-hooks' `shellHook`. Without it, "we have pre-commit" would be a
lie, because the hook file would never appear. With direnv, a `cd` into the repo already enters
here, so the hook installs itself in any fresh clone.

`enabledPackages` brings statix, deadnix and nixfmt at the version the hooks use, so running them by
hand inside the shell is identical to what the hook will run.

**`mkShellNoCC` and NOT `mkShell`**: nothing here compiles C, they are Nix linters and the LSP.
`mkShell` drags in the stdenv with the cc/binutils wrapper, and the VISIBLE effect is direnv dumping
a paragraph of `export +AR +AS +CC +CXX +LD +NM +OBJCOPY +RANLIB +NIX_CFLAGS_COMPILE
+NIX_HARDENING_ENABLE ...` on every `cd` into the repo. Without the CC that shortens to what
matters, and the shell is lighter to build.

## The CI, and the private input

`.github/workflows/nix.yml` runs EXACTLY the local gate on every push.

**Why it exists**: the flake's gate only runs when somebody TYPES `nix flake check`. A standard that
depends on remembering is an intention, not a standard, and the intention is the first thing to
evaporate in a rushed rebuild in 2027.

**Why it is a real `nix flake check` today (04/08/2026)**: this flake has a PRIVATE input,
`ssh://git@github.com/v1cferr/duo-streak-daemon.git`, and Nix fetches ALL the inputs in the lock
when evaluating, not only the ones the requested output uses. That is why the CI used to run
statix/deadnix/nixfmt straight from nixpkgs: the LOCAL flake was never evaluated and no credential
entered the game.

The way out is `--override-input`, which swaps the input BEFORE the fetch for an EMPTY directory
versioned in `ci/stub-duo`. No deploy key, no secret in Actions, and the flake evaluates in full.
Verified on 04/08/2026: "checking NixOS configuration 'nixosConfigurations.nixos-kingston'" plus
"all checks passed!". Why empty is enough is in `ci/stub-duo/.gitkeep`.

**What that bought**, and they were two real holes:

1. The CI did not verify that `nixosConfigurations.nixos-kingston` EVALUATES, so a module error
   passed green and only showed up on the `rebuild`. Now it fails there. (EVALUATING IS NOT
   BUILDING, which is why `checks.packages` exists.)
2. The three `nix run` invocations were a THIRD definition of the same rule `flake.nix` and the
   pre-commit hook already defined: rule 14's silent drift waiting to happen. Now touching the
   hooks changes the CI automatically, and the `env NIXPKGS` that existed only to pin the linters'
   version goes away too, since they come from `flake.lock`, identical to the local ones by
   construction.

**The cost, accepted**: `flake check` fetches ALL the inputs (~1.43 GiB across 19) and evaluates the
whole config, so the CI went from seconds to minutes. The trade is machine time for coverage and a
single definition. If it ever gets annoying, the way back is this file in the history, not undoing
`ci/stub-duo`, which is useful anyway for running `flake check` in any clone without the private
key.

### Two community tools looked at and REJECTED (16/08/2026)

**`DeterminateSystems/flake-checker-action`** is what the community reaches for to catch input
drift, and it loses here on two counts. It defaults to `send-statistics: true`, which contradicts
the no-vendor decision recorded just below for the installer; and its headline check is "the root
Nixpkgs input has been updated within the last 30 days", which fights a RELEASE PIN on purpose,
since only backports land in `nixos-26.05` and the age of the pin is not a defect. `check-outdated`
can be turned off, but a checker running with its main check disabled is not worth an action.

**An input-age check of our own** was prototyped and dropped for a subtler reason, worth writing
down because it looks correct: `lastModified` in `flake.lock` is the UPSTREAM commit date, not the
date we last fetched. `disko` measured 66 days old with `nix flake update` freshly run, purely
because disko has not had a commit in 66 days. Measuring OUR staleness would mean measuring the
lock file's git mtime, which is a much weaker signal than it looks. See
[`dead-config.md`](dead-config.md) for the other checks that were prototyped and refused.

**`cachix/install-nix-action` and NOT `DeterminateSystems/nix-installer-action`**: the second is
faster and brings a cache for free, but it installs the Determinate Nix distribution (its support
for upstream Nix ended on 01/01/2026) and pulls toward FlakeHub Cache. For a personal repo that has
to last until 2032+, upstream Nix with no vendor is the safer bet, and switching later is 1 line.

The `concurrency` block cancels the previous run of the same ref, because three commits in a row
would otherwise queue three CIs when only the last one matters.

### Plan B: a deploy key, if the empty stub ever does NOT do

Only necessary if a module starts READING content from the private repo at EVALUATION time; today
`system/services/duo.nix` only uses the input as a Docker build context. On that day the stub would
need the file being read, and if that becomes impractical:

1. Generate a key pair just for this: `ssh-keygen -t ed25519 -f ci_key -N ""`
2. The public one goes to the duo-streak-daemon repo, Settings > Deploy keys, read only.
3. The private one goes to the dotfiles repo, Settings > Secrets > Actions > `SSH_PRIVATE_KEY`.
4. Add `webfactory/ssh-agent@v0.9.0` before the check and drop the `--override-input`.

A DEDICATED key, never your personal one: a deploy key leaves the repo with one click, while a
compromised personal key is your whole GitHub.

## statix: the two lints turned off, and why

`statix.toml`. THE MEASUREMENT that motivated the file (03/08/2026, 79 files): 77 findings, of which
63 were `W20 repeated_keys` (82% of everything), 10 were `W10 empty_pattern` and 4 were
`W4 manual_inherit_from`.

The 4 W4s were FIXED, becoming `inherit (x) a b;`. The other two are turned off, not for being
annoying but for being WRONG for a repo of NixOS modules. **A lint we ignore in practice is worse
than a lint turned off**: it trains the eye to skip over the whole output, the real finding
included.

**`repeated_keys`** wants `services.openssh = {…}` and `services.fail2ban = {…}` to become a single
`services = { … }`. Refused for three reasons:

1. THE DOTTED PATH IS NIXOS' IDIOM. All of nixpkgs and every doc write `services.foo.enable = true`.
   Following it would leave this repo diverging from the ecosystem, the opposite of what "best
   practices" means.
2. IT MAKES THE DIFF WORSE. With top-level attributes, adding or removing a service is an isolated
   hunk. Nested, every change touches the structure around it and the diff grows with nothing else
   having changed.
3. IT MAKES READING THIS REPO WORSE. Nesting everything under one key would push comment and value
   to 3-4 levels of indentation, and `system/net/network.nix` would become a giant ~100-line
   attrset.

It is a TASTE lint with a defensible side (grouping what belongs to the same domain), but the repo's
taste is nixpkgs' taste, and it is declared here instead of being ignored in silence on every run.

**`empty_pattern`** wants `_:` instead of `{ ... }:` when a module uses no argument. Refused because
`{ ... }:` is the NixOS MODULE SIGNATURE: whoever opens the file sees right away that it receives
the module args and happens to use none. `_:` only says "it receives something and ignores it". And
when `pkgs` is needed, the edit is `{ ... }:` to `{ pkgs, ... }:`, smaller than rebuilding from
`_:`. This is the weaker of the two arguments; if I ever prefer `_:`, it is just removing it here
and running `statix fix`.
