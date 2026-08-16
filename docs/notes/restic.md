# restic

Module: [`system/services/restic.nix`](../../system/services/restic.nix)

The declarative backup: user state to Google Drive, encrypted, deduplicated and versioned.

## The pair with btrbk

The hourly local snapshot ([`btrbk.nix`](../../system/services/btrbk.nix)) covers "I just
overwrote it". THIS one covers "the disk died / the house burned down".

A snapshot on the same disk is not a backup, and a sync is not a backup, because deleting
propagates. Only restic is a backup (rule 6). The password is a secret in sops; without it the
repo is encrypted garbage.

## Why the Drive only, since 05/08/2026

The destination used to be the Seagate HDD and it left. It was not about space: it was the ONLY
copy of the live home, on a ~2009 Momentus 7200.4 with **840 thousand load cycles** (40% past
spec) and **348 CRC errors**, INSIDE the same machine, so it disappears with it in a theft or a
fire. An offsite copy wins on the failure modes that actually happen.

The accepted price: restoring goes over the network and depends on the Google account. Measured on
the 1st snapshot: 40.6 GiB read, 23.6 GiB on the wire, 15 min.

**The Drive is verified**: `check --read-data` rereading the 189 packs returned "no errors were
found" on 05/08/2026.

**The Seagate repo is still NOT deleted, and that is not indecision, it is HISTORY.** The Drive has
1 snapshot and the Seagate has 13, with the 7d/4w/6m window. Deleting now would lose every version
older than today, which is exactly what saves you when a file got corrupted weeks ago and nobody
noticed. The repo is static and the disk has 195 G free, so keeping it costs nothing. Delete it
when the Drive accumulates an equivalent window.

With no target declared, the `restic-home` wrapper stops existing, so reading the frozen repo is
restic directly:

```sh
sudo restic -r /mnt/seagate-old/restic --password-file /run/secrets/restic_password snapshots
```

## A user FUSE mount inside `paths` breaks the backup by construction

**This is the biggest lesson in the file, and it has appeared three times under different names.**

The backup runs as ROOT, and root does not enter somebody else's FUSE. An `lstat` on a user mount
returns `permission denied`, restic exits 3, and since `backup` is the FIRST of three ExecStart
entries, the `unlock` and the `forget --prune` never run.

**First victim, `~/FAI-workstation`** (05/08/2026). Intermittent, because the mount only exists
while the FAI VPN is up: the 06:44 run passed, the 14:55 one did not. `--one-file-system` does not
save you: it prevents DESCENDING into the mount, but restic still lstats the mount point.

**Second victim, `~/Drive`** (06/08/2026), and this one hurt more because it is PERMANENT. The
Drive mounts on EVERY boot, so the service started failing EVERY NIGHT and the prune stopped
running for good. Measured on 09/08/2026: the last successful `forget --prune` was 05/08 15:46,
four days with no retention applied at all.

**The size of the damage was small, and that matters so the next case is not overestimated**: the
recovery run removed ONE snapshot and freed 4.9 MiB in 14 s. With `--keep-daily 7` and only 5
distinct days in the repo, nothing had aged out of the window yet, and the only excess was a
same-day duplicate. The real damage would start after ~7 distinct days.

**What actually has teeth is the `unlock`**, which is also an ExecStart and also was not running: a
stuck lock from an interrupted run BLOCKS the entire backup, and that does not depend on elapsed
time.

And a failing service is not only noise: "restic failed" becomes the normal state, and then the
REAL failure (the Drive down, an expired OAuth token, a stuck lock) arrives with nothing to
distinguish it from the usual noise.

**A new mount point in `/home/v1cferr` enters the exclude list in the same commit that creates it.**

## The writable rclone.conf copy is not cosmetic

The module's `rcloneConfigFile` only sets `RCLONE_CONFIG=<path>`, and this service runs as ROOT.
rclone renews the OAuth token and persists the new one OVER the file it was pointed at, and root
has permission, so it succeeds, and the new file is born `root:users`.

That ERASES the `owner = "v1cferr"` sops put on `/run/secrets/rclone_gdrive_conf`, and every
consumer that runs as the USER starts dying unable to read it: `backup-browse`, `~/Drive` and,
since 11/08/2026 and most sensitive because it is a service and not a command, the permanent mount
of the old Arch archive.

Diagnosed on 07/08/2026: boot at 07:29, sops sets v1cferr, the delayed 03:00 backup ran at
07:54:39, and the secret's owner became `root:users` at 07:54:40. In practice the backup browser
was broken almost always and "fixed itself" on reboot.

The user reads the copy read-only (0400), so they cannot reintroduce the bug.

Two ordering details around it:

- **`mkAfter` for the PATH**, because the nixpkgs module puts ONLY ssh on it
  (`path = [ config.programs.ssh.package ]`) and restic's `rclone:` backend EXECUTES the rclone
  binary. Without it the service dies at the start with
  `rclone: executable file not found in $PATH`. That trap already cost the entire Arch archive
  service.
- **`mkBefore` for the copy**, because `initialize = true` puts a `restic cat config || restic init`
  at the beginning of the SAME preStart, and that already talks to the Drive. Copying after it
  would make the service die on the first command with a nonexistent rclone.conf.

**Never the `rcloneConfig` attrset option**: it leaks the token into `/nix/store`, which is
world-readable (rule 12).

## The mountpoint lives in /mnt, not in the home

`/mnt/backup` exists so the backup can be browsed in the file manager. It is owned by the USER,
because whoever mounts has to be the user: a FUSE mount is private, so `sudo restic mount` produces
a folder Dolphin cannot open, which was the defect of the alias's first version.

It is outside the home ON PURPOSE: a mountpoint inside `/home/v1cferr` would enter the backup's
`paths` and fall into the exact trap above.

`/mnt/arch-antigo` was created here until 11/08/2026 and moved to
[`arch-legacy.nix`](../../system/services/arch-legacy.nix), because that mount stopped being an
on-demand lookup and became a permanent service, so its directory cannot depend on this toggle.

## Three tuning decisions that are about viability, not speed

**Pack size** is what decides whether this works at all: on the Drive the cost is per API CALL, not
per byte, and there are 255 THOUSAND files here. In 128 MiB objects (restic's maximum) that becomes
a few thousand objects.

**A prune ceiling**, because pruning a remote repo REPACKS: it downloads partially used packs and
uploads them back. With no ceiling a bad prune becomes hours of traffic. What does not fit today
gets pruned on the next run.

**`--read-data-subset` stays OUT.** Rereading means DOWNLOADING, and 10% a day of a ~24 GiB repo
would be ~2.4 GiB of download EVERY DAY, forever. The scheduled check is STRUCTURAL only (indexes
and trees), which is metadata and comes cheap. Reading the data in full is manual and deliberate:

```sh
sudo restic-home-gdrive check --read-data
```

## Browsing the backup

The repo is an encrypted blob: rclone does NOT decrypt it, restic does.

```sh
sudo restic-home-gdrive mount /mnt/backup    # Ctrl+C unmounts
```

The wrapper the module generates already carries `RCLONE_CONFIG`, the password and rclone on the
PATH. The user-facing alias is `backup-browse` (see [shell](shell.md)), which runs with no sudo for
the FUSE reason above.

## The CS2 saves, and why they need their own mirror

`home/services/cs2-saves-backup.nix`.

restic EXCLUDES `~/.local/share/bottles` (Wine prefixes, ~154 G that is reinstallable), but the
Cities: Skylines II SAVES live in there and are irreplaceable: a pirated repack, with NO Steam
Cloud.

The timer MIRRORS the saves into `~/CS2-Saves-Backup`, which sits in `/home`, OUTSIDE the exclude,
and the daily restic takes it to the off-disk Seagate. It closes the "state = restic" rule and the
note in this module itself ("saves… back them up separately").

`rsync --delete`, so the mirror reflects the CURRENT state. The versioned history, for undoing an
accidental overwrite, is what restic keeps with keep-daily/weekly.

It is cheap: rsync is incremental and a no-op when nothing changed, so running it hourly does not
weigh. It mirrors 5 min after boot and every hour, which catches a game session that just closed.
The script only acts if a save already exists, so it does not fail before the first game.

For another game later, replicate the src/dst pair in a new module.

## ~/Drive: a window, not a backup

`home/services/drive-mount.nix` mounts the ROOT of Google Drive as a local folder (rclone mount
plus a VFS cache), so it shows up in Dolphin as a normal folder with a bookmark. It serves the real
case: "sometimes I need a file I do not have here but that is on the Drive". You see everything
right away, with no downloading.

**It is a WINDOW into the Drive: deleting here deletes there, for real.** The backup is restic, and
that is the only thing that satisfies rule 6.

The restic repo lives in `BACKUPS_EX-B560M-V5/` and is EXCLUDED from the mount: it is ~48 GiB of
encrypted blobs that would only pollute the file manager, and an accidental Delete in there
CORRUPTS the backup. To look inside the backup there is `backup-browse`, a restic mount, read-only.

### Why a mount and not bisync (decided 05/08/2026)

The first version was `rclone bisync`. It was swapped after LISTING the remote and seeing that the
root holds ~19.6 GiB of real archive (family photos, documents):

- bisync would download those 19.6 GiB onto the NVMe to give the same access the mount gives with
  zero downloading;
- and a sync PROPAGATES, so deleting locally would delete on the Drive, family folder included. In
  a mount every operation is explicit and singular; there is no algorithm reconciling two listings
  that could conclude "the other side should be empty".

What you lose is OFFLINE access and editing with no network. An accepted trade, since what needs to
work offline is the backup, and that is another module.

### The three unit details

- **`Type = "notify"`**, supported by rclone (it is in `rclone mount --help`, the systemd section):
  the unit only goes "started" AFTER the mountpoint is ready. With `Type=simple`, Dolphin could
  open the folder before it exists and cache it as "empty". This is exactly what
  [`arch-legacy.md`](arch-legacy.md) could NOT do, since `restic mount` has no sd_notify.
- **A WRITABLE COPY of rclone.conf.** rclone renews the OAuth token and tries to persist the new
  one into the config file; against the sops secret (0400, in a non-writable directory) that
  becomes `Failed to save config … permission denied`. Not fatal, but a recurring ERROR in the
  journal hiding a real error. `%t` is `XDG_RUNTIME_DIR`, a tmpfs, 0600.
  The `--config` goes on the COMMAND and NOT as `RCLONE_CONFIG` in the environment, because
  `programs.rclone` generates the rclone.conf for the `faiws` remote and exporting the variable
  would make the FAI mount look for its remote in the wrong file. rclone's docs also warn that a
  systemd unit does not inherit the environment, another reason for the flag.
- **`ExecStopPost` force-unmounts.** rclone unmounts on its own on SIGTERM; this is the safety net
  for a hung mount (the `-` ignores an already-unmounted one). It has to be NixOS' setuid WRAPPER,
  since the package's fusermount3 has no privilege.

`StartLimitIntervalSec = 0` because at login the network usually takes a few seconds, and without
it systemd would give up after 5 quick failures and the folder would stay empty until a manual
start.

### THE MOUNTPOINT HAS TO BE EMPTY

rclone refuses with "…is not empty, use --allow-non-empty to mount anyway", and
`--allow-non-empty` stays OUT on purpose: mounting over an existing file HIDES it, and then you
have invisible data that only reappears when the mount goes down.

It cost the first start (05/08/2026): the bisync version of this module created an `RCLONE_TEST`
here, and the orphaned 0-byte file locked the mount into a restart loop. **If the mount does not
come up, check `ls -a ~/Drive` BEFORE suspecting the network.**
