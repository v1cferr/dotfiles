# shell

Modules: [`home/shell/zsh.nix`](../../../home/shell/zsh.nix),
[`home/shell/cli.nix`](../../../home/shell/cli.nix),
[`home/shell/ntfy.nix`](../../../home/shell/ntfy.nix)

zsh, the maintenance aliases and the modern CLI toolkit.

## The three maintenance aliases are COMPOSED, not written three times

`upgrade` IS `update && rebuild` by definition. Restating it in full (as it was until 06/08/2026)
is the same rule in two places, so the day only one copy changes, `upgrade` stops being what its
name says and nobody notices. That is rule 11 applied to a shell string.

```text
rebuild   nh os switch <flake> && hyprctl -i 0 reload
update    vscode-bump && curseforge-bump && nix flake update && vscode-extensions-dump
upgrade   update && rebuild
```

**The order inside `update` is load-bearing.** `vscode-bump` runs BEFORE `nix flake update`
because the `vscode-tarball` input has a versioned URL, so it is the bump that raises the number
(see [version-bumps](version-bumps.md)). If it fails (the API down, the repo in another format)
the `&&` stops there and nothing is applied with the repo half-edited.

`vscode-extensions-dump` goes LAST and touches no input: it rewrites the mirror of the installed
extensions so the repo shows in the diff which extension came or went. Its trigger is `update` and
not `rebuild` because `update` is the maintenance ritual; the price is the mirror lagging between
two updates, which is fine for a record nobody consumes at runtime.

**`update` runs as the USER**, and only on success goes on to the rebuild as root. The user is who
holds the SSH key for the private inputs (duo-streak-daemon), and a broken lock never gets applied.

## The path goes in EXPLICITLY, not through NH_FLAKE

Learned the hard way on 03/08/2026. `programs.nh.flake` publishes the variable through
`environment.variables`, which becomes an `export` in `/etc/set-environment` and is only read at
LOGIN. The graphical session in progress does not have it, and a new terminal inherits the
session's environment instead of rereading `/etc/profile`.

So the alias broke exactly after the switch that introduced it, with the misleading message
`no flake found at /etc/nixos/flake.nix`, as if the config were in the wrong place. Passing the
path makes it work on the first `rebuild` with no relogin. `programs.nh.flake` still holds, since
it is the SSOT read here and it serves a bare `nh`; it just is not a dependency of the alias
anymore.

## `hyprctl -i 0` is what makes rebuild work over SSH

Without `-i 0`, hyprctl demands `HYPRLAND_INSTANCE_SIGNATURE`, which only exists inside the
graphical session. Rebuilding from outside failed SILENTLY and the new Hyprland config was not
applied (29/07). The `|| true` keeps the rebuild's exit code as the one that matters, even with no
Hyprland running.

`nh os switch` carries no `sudo` on purpose: nh elevates on its own at activation time, so the
build runs as the user and only the activation asks for a password.

## `gc` deletes ALL old generations

`nix-collect-garbage -d` is not "clean the ancient ones", it is all of them. After running it
there is no rollback to yesterday's generation and no entry for it in GRUB. That is what you want
when the intent is freeing the maximum; for plain hygiene, `--delete-older-than 7d` cleans nearly
as much and PRESERVES the emergency exit. The automatic weekly GC does use `--delete-older-than
30d`.

## `backup-browse` has no sudo, and that is the point

A FUSE mount is private to whoever mounted it, so `sudo restic mount` produces a folder Dolphin
does NOT open, which was the first version's defect. Running as the user, the folder is theirs and
the file manager gets in. It requires the restic passwords to be readable without sudo (see
[secrets](secrets.md)) and the mountpoint created by tmpfiles.

It is an alias and not a script because it is a one-line command (rule 7).

Only the HOME one is left. The twin `arch-browse` DIED on 11/08/2026: that mount became permanent
and has a declared owner, so `/mnt/arch-antigo` is already mounted and there is no command to run.
This one stays on demand on purpose, because the HOME repo is precisely the one the daily prune
needs to lock by itself.

`backup-verify` rereads ALL the repo's data to prove a restore is possible, downloading ~24 GiB in
~4 min. Deliberately manual: automated it would be a daily download.

## The CLI toolkit, chosen by real gaps

Every binary in `cli.nix` filled a gap in a concrete debugging session on this machine, not a slot
in an "awesome" list.

| Tool | The gap it filled |
| --- | --- |
| `delta` | reading a diff is the most repeated operation here, and git's raw diff is monochrome |
| `dust` | "what is taking space HERE", over SSH, with no graphical session |
| `doggo` plus `dnsutils` | on 03/08, debugging the DDNS, `dig` did not exist and the query went out through `curl` against a DoH API |
| `procs` | a whole day of `pgrep -a` / `ps -o` hunting Hyprland, hyprlock and sunshine |
| `hyperfine` | nearly every comment in this repo starts with "MEASURED", and `time` measures one sample while hyperfine measures the distribution |

**difftastic was passed over.** It solves another problem (a structural diff, for "I renamed and
reindented and the diff exploded"), and the community uses both together with delta as the
day-to-day pager. It comes in if the need shows up; installing both now would be choosing without
having the problem.

**`side-by-side` is off in delta** because the `.nix` files here carry a comment block per config
and lines of ~90 columns, so at 1920x1080 two columns break everything and the diff comes out
WORSE than one column. Per invocation it still works: `git diff --side-by-side`.

**zoxide's init is reinjected at the END of `.zshrc`.** home-manager injects it early (mkOrder
851), which trips zoxide's doctor with "initialize at the end". The correct fix
(home-manager#9349) is turning the automatic integration off and reinjecting at mkOrder 2000,
after every mkAfter, so the doctor is genuinely satisfied with nothing silenced.

### atuin takes Ctrl+R from fzf, and it is LOAD ORDER that decides

Both bind `^R`, so whichever initializes LAST wins, and neither module says so out loud.
Measured in the pinned home-manager: fzf injects at `mkOrder 910` (its own comment explains it,
oh-my-zsh is 800 and would otherwise take precedence) and atuin injects with NO `mkOrder`, which
lands at the default 1000. So 910 then 1000 then zoxide's 2000, and atuin wins.

It works out with nothing declared, which is exactly why it is written down: if fzf's order ever
moves past 1000, Ctrl+R silently goes back to `fzf-history-widget` and nothing fails. The other
fzf bindings are untouched, since atuin only claims `^R`: Ctrl+T (file) and Alt+C (cd) stay.

Two halves of atuin are STATE and not declarable (rule 6): `atuin login` for the sync account,
and `atuin import auto` to pull the existing `~/.zsh_history` into the database. Until the
import runs, the search is empty and it looks broken rather than new.

### And `_ZO_DOCTOR=0` on top of that, which is NOT undoing the fix above

MEASURED on 08/09/2026, because the warning kept showing up in Claude Code's output long after
mkOrder 2000 had fixed the real problem, and the two look identical on screen.

What the doctor actually tests is one line, and it is not about init order at all:

```zsh
[[ ${chpwd_functions[(Ie)__zoxide_hook]:-} -eq 0 ]] || return 0
```

`(Ie)` returns the INDEX of `__zoxide_hook` in `chpwd_functions`, or 0 when it is absent, so
`-eq 0` means "not registered", the `return` is skipped and it prints. It runs from INSIDE the
`cd` function (`--cmd cd`), never at init, so it can only ever fire on an actual `cd`.

In the interactive shell it is satisfied, and that is the measurement that matters:
`zsh -i -c 'print -r -- $chpwd_functions'` gives `_direnv_hook __zoxide_hook`, the hook present
and LAST. Sourcing `.zshrc` in a non-interactive shell gives the same array. Nothing warns.

What warns is an AGENT'S SHELL, and the reason is worth knowing before blaming this config:
Claude Code does not re-source `.zshrc` per command, it replays a snapshot of the shell's
functions from `~/.claude/shell-snapshots/`. That snapshot carries every zoxide function, the
`cd` wrapper and the doctor included, and its ONLY mention of `chpwd_functions` is the doctor's
own test quoted above. So the wrapper exists, the registration never re-runs, and `cd` reports a
hook that genuinely is missing THERE.

Which makes it a true statement about a shell I do not control and a false one about this repo.
It is also the behavior I would pick anyway: directories an agent visits should not enter my
frecency database. `home.sessionVariables` is inherited by every child process, so the variable
reaches that shell where a guard inside `.zshrc` never could. The mkOrder 2000 reinjection STAYS,
and removing it would bring the real problem back with the warning now muted.

## `notify` never takes the caller down

The ntfy topic is the password: on the public ntfy.sh, whoever knows the topic name can read and
publish, which is why it lives in sops and the script reads `/run/secrets/ntfy_topic` at runtime.
Use a random topic, not "v1cferr".

With the secret not provisioned it WARNS on stderr and exits 0. A backup should not fail because
the warning did not go out.

The message goes as JSON and not as a header, because an HTTP header is ASCII and a title with an
accent would break at the wrong moment.

Turning it on, in this order, or the switch breaks: create the Bitwarden item, add the line to
`bitwarden-secrets.json`, run `sync-secrets`, then rebuild. Entering the index makes sops DECLARE
the secret, and a declared secret with no value in `secrets.yaml` passes the build and breaks the
ACTIVATION.
