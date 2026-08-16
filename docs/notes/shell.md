# shell

Modules: [`home/shell/zsh.nix`](../../home/shell/zsh.nix),
[`home/shell/cli.nix`](../../home/shell/cli.nix),
[`home/shell/ntfy.nix`](../../home/shell/ntfy.nix)

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
