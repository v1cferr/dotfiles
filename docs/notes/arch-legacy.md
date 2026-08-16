# The old Arch archive, mounted permanently

Two modules, one artifact:

- `system/services/arch-legacy.nix`: the mountpoint and the path's SSOT.
- `home/services/arch-legacy-mount.nix`: what actually mounts it.

## Why the split

A FUSE mount is private to whoever mounted it, so `sudo restic mount` produces a folder Dolphin
cannot open. That was the defect of the first version. Root only comes in to CREATE the directory,
because `/mnt` is its and the user cannot write there.

The option is declared on the SYSTEM side and not in the home module because of rule 11: the
`tmpfiles` rule is a system module and consumes the path, and a system module cannot read a
home-manager option. The home consumers (the unit and the Dolphin bookmark) read it through
`osConfig.my.archAntigo.*`.

The mountpoint is OUTSIDE `/home` on purpose. Inside `/home/v1cferr` it would enter the backup's
`paths` and fall into the same trap as `~/Drive` and `~/FAI-workstation`: root cannot `lstat` the
user's FUSE, restic exits 3, and `forget --prune` stops running. See `docs/notes/restic.md`.

## Why it moved out of restic.nix (11/08/2026)

The directory used to be created inside `restic.nix`, alongside `/mnt/backup`. There it was tied
to the `restic` toggle: turning the backup off would start taking down a mount that is now
PERMANENT, and the failure would show up far from the cause (a mount with no mountpoint).
`/mnt/backup` stays there because it remains an on-demand lookup by `backup-browse`, which is
restic's domain.

## Why it stopped being an alias

It used to be the `arch-browse` alias, run by hand and alive only as long as the terminal stayed
open. The symptom that killed it (11/08/2026): opening the Dolphin bookmark and seeing an EMPTY
folder. There was no defect at all. The secrets were readable, the repo was answering, the mount
came up in ~20 s when asked. The defect was the DESIGN: automation with no declared owner (rule
15) that depended on remembering the command and never closing that terminal.

## The price of leaving it up (measured 11/08/2026)

~195 MiB of resident RSS: 115 MiB from restic (the repo index in memory, a 44.6 GiB snapshot) plus
79 MiB from `rclone serve restic`. On the NETWORK, while idle, it is ZERO: restic does not poll,
it only reads when somebody reads.

The Dolphin bookmark's comment used to say a permanent mount would be "an open connection and a
lock on the repo for nothing". The first half was true and became a conscious choice; the second
half is what `--no-lock` solves.

## Why `--no-lock`, and the premise behind it

Every `restic mount` creates a non-exclusive lock and renews it every ~5 min; a mount that dies
without exiting cleanly leaves it STUCK. On 11/08/2026 the repo had 3 locks: one from the live
mount and two leftovers from `arch-browse` on 05/08 and 08/08. A permanent mount was only going to
make that worse, and it would also write to the offsite repo every 5 min forever.

What the lock protects is a read concurrent with a prune. This repo is STATIC: nothing has written
to it since 01/08/2026, when the Kingston was formatted, and no routine prunes it (the automatic
`forget --prune` only looks at the HOME repo). If something ever starts writing here, `--no-lock`
is the first line to go.

## Readiness, and why it is not `Type = "notify"`

`restic mount` does NOT speak sd_notify (checked: no "notify" in 0.18.1's `restic mount --help`),
so there is no copying what `~/Drive` does. With `Type = simple` systemd would call the unit ready
the instant the process is born, which is to say BEFORE the mountpoint exists, and Dolphin would
open the empty folder and cache that: exactly the symptom this module came to solve.

So `ExecStartPost` blocks "started" until the mount actually shows up: 120 attempts of 1 s. A cold
cache (the index not yet downloaded from the Drive) took ~20 s in the measurement; the slack is
for a bad network, and the ceiling exists so `Restart=on-failure` can try again instead of leaving
the unit "activating" forever. `TimeoutStartSec = 180` because 120 s of waiting plus restic's
startup do not fit in the default 90 s, and blowing past it KILLS the unit mid-wait.

It is a `writeShellApplication` and not a loose `.sh` nor a two-line `sh -c` (rule 7): the logic
lives in the build, and that way it goes through shellcheck.

## Two rclone details

- Its OWN writable copy of `rclone.conf` (`%t/rclone-arch-antigo.conf`), not `~/Drive`'s. rclone
  renews the OAuth token and tries to persist it over the config; against the sops secret (0400,
  in a non-writable directory) that becomes a recurring `permission denied` ERROR in the journal
  hiding a real one. Two units rewriting the SAME copy is the stomping the backup did on the
  secret (07/08/2026).
- `RCLONE_CONFIG` in the unit's Environment is safe here: restic has no flag for pointing at
  rclone.conf, only the backend reads it, and it reads it from the environment. The warning in
  `drive-mount.nix` is about exporting it from the SESSION, which would make the FAI mount look
  for its `faiws` remote in the wrong file.
- `-o rclone.program=<store path>`: the `rclone:` backend EXECUTES the rclone binary, and a
  systemd unit does not inherit the session's PATH. This is the same trap that once cost the whole
  backup service.

## If the network drops

A read hangs until rclone's timeout and the mount can go zombie ("Transport endpoint is not
connected"). The remedy is `systemctl --user restart arch-antigo-mount`; the `ExecStopPost`
force-unmounts the leftovers before coming back up. Same exposure as `~/Drive`, which has run this
way since 05/08/2026 with no incident.
