# restic, and why the backup is gone

Module: NONE since 24/09/2026. The service module under `system/services/` was deleted, and with
it the `restic` toggle, the `/mnt/backup` mountpoint and the `backup-browse` / `backup-verify`
aliases.

**This machine has no automatic backup today.** What is left is
[btrbk](btrbk.md): hourly snapshots of `@home` on the SAME disk they protect, which answers "I
just overwrote it" and nothing else. A dead disk, a theft or a fire takes everything. That is a
dated, deliberate gap and not an oversight, and it closes when new storage arrives:
see [open-items](../../open-items.md).

## What killed it: a 15 GiB quota holding 130 GiB

MEASURED on 24/09/2026, with the account on the free tier:

| what | GiB | note |
| --- | ---: | --- |
| `BACKUPS_EX-B560M-V5/HOME` | 55.08 | the daily backup, 591 objects |
| `BACKUPS_EX-B560M-V5/ARCH-KINGSTON` | 23.67 | the Arch archive, a different repo |
| restic packs IN THE TRASH | 30.62 | 577 objects, 100% of the trash |
| `César/` (a Minecraft world plus saves) | 17.77 | byte-identical copies existed in `~/Downloads` |
| everything personal, all of it together | ~2.8 | |
| **total in use** | **130.02** | against a quota of **15** |

restic alone was **109.37 GiB, or 84% of the usage**. Nothing else came close, and no amount of
tidying the personal files was ever going to fix it.

The timeline is short and it matters: the last snapshot saved was **16/09 06:59**, the first
`storageQuotaExceeded` came at **17/09 05:54**, and the service then failed every single night
for 8 days. Over quota, the run cannot even create its LOCK, so it burns ~15 min retrying and
dies. The `Fatal: config file already exists` at the tail of the journal is `initialize = true`
making noise afterwards, NOT the cause.

## The trash was the leak, and it had never been written down

**This is the lesson of the file.** The `forget --prune` was working: the journal shows
`collecting packs for deletion and repacking` every day from 08/09 to 16/09. It deleted the old
packs exactly as configured.

They went to the Drive's TRASH, because that is what rclone's Drive backend does with a delete by
default, and **a trashed file goes on counting against the quota**. So every prune since the very
first one was moving bytes from one column to another while the account filled up. 30.62 GiB of
pure garbage, and the prune had no way of knowing: from restic's side the packs were gone.

Emptying the trash was the single biggest win of the cleanup, at zero risk, and it needed no
decision about the backup at all.

**Whatever the next destination is, the delete has to be permanent.** On a Drive backend that is
`--drive-use-trash=false`. Any backend with a recycle bin, a versioning policy or a soft delete
has the same trap under another name, and it is worth proving with a `rclone about` BEFORE and
AFTER a prune rather than trusting the retention settings.

## What survived, and how to read it

Two repos, both on the Seagate, both frozen. **The Drive's `HOME` repo was deleted permanently on
24/09/2026 WITHOUT being copied down**, a deliberate call, so the snapshot window from 05/08 to
16/09 no longer exists anywhere.

```sh
# the original home repo, 13 snapshots, frozen since 05/08/2026
sudo restic -r /mnt/seagate-old/restic \
  --password-file /run/secrets/restic_password snapshots

# the old Arch archive, copied off the Drive on 24/09/2026
restic -r /mnt/seagate-old/restic-arch-kingston \
  --password-file /run/secrets/restic_password_arch_kingston snapshots
```

The Arch one needs no `sudo` (the directory belongs to the user) and is normally read through
`/mnt/arch-antigo`, which mounts it permanently: [arch-legacy](arch-legacy.md).

The nixpkgs module used to generate a wrapper PER REPO, and that module left with the daily
backup. The `restic` client in `system/packages.nix` is now the only way in, which is exactly why
it is declared there.

**The two sops secrets STAY.** `restic_password` and `restic_password_arch_kingston` are not
leftovers: without them both repos above are encrypted garbage.

## What the Seagate is now, and the debt in it

It stopped being a backup destination on 05/08/2026 and became cold storage. The reason has not
changed and it is not about space: it is a ~2009 Momentus 7200.4 with **840 thousand load
cycles** (40% past spec) and **348 CRC errors**, INSIDE this machine, so it disappears with it in
a theft or a fire.

**The Arch archive is now ONE copy on that disk.** It holds a 44.6 GiB snapshot with no source to
regenerate it. That is a known debt, written down here so it is not discovered later.

## Lessons that outlived the service

They cost real incidents, they are not about restic specifically, and the next destination
inherits every one of them.

### A user FUSE mount inside `paths` breaks the backup by construction

The backup ran as ROOT, and root does not enter somebody else's FUSE. An `lstat` on a user mount
returns `permission denied`, restic exits 3, and since `backup` was the FIRST of three ExecStart
entries, the `unlock` and the `forget --prune` never ran.

It happened three times under different names. `~/FAI-workstation` (05/08/2026), intermittent
because the mount only exists while the FAI VPN is up. `~/Drive` (06/08/2026), and that one hurt
more because it is PERMANENT: the prune stopped for good, and on 09/08 the last successful one
was four days old. `--one-file-system` does NOT save you, since it prevents DESCENDING into the
mount but restic still lstats the mount point.

**A new mount point in `/home/v1cferr` enters the exclude list in the same commit that creates
it.** That rule is why `/mnt/backup` and `/mnt/arch-antigo` live outside the home.

What actually had teeth was the `unlock`, also an ExecStart and also not running: a stuck lock
from an interrupted run BLOCKS everything, and that does not depend on elapsed time.

And a failing service is not only noise. "restic failed" becomes the normal state, and then the
REAL failure arrives with nothing to distinguish it from the usual noise. That is precisely how 8
days of `storageQuotaExceeded` went by unnoticed in September.

### A writable copy of rclone.conf, never the secret itself

rclone renews the OAuth token and persists it OVER the file it was pointed at. Running as root it
succeeds, and the new file is born `root:users`, which ERASES the `owner = "v1cferr"` that sops
set on `/run/secrets/rclone_gdrive_conf`. Every consumer running as the USER then dies unable to
read it.

Diagnosed on 07/08/2026: boot at 07:29, sops sets v1cferr, the delayed backup ran at 07:54:39,
and the secret's owner became `root:users` at 07:54:40. The fix is `install -m600` into
`$XDG_RUNTIME_DIR` and pointing at the copy. This still applies to
[`drive-mount.nix`](../../../home/services/drive-mount.nix), which is why each unit keeps its OWN
copy.

**Never the `rcloneConfig` attrset option**: it leaks the token into `/nix/store`, which is
world-readable (rule 12).

### Pack size decides viability on a per-call backend

On the Drive the cost is per API CALL, not per byte, and there were 255 thousand files. At
`--pack-size=128` (restic's maximum, in MiB) that became a few hundred objects instead of
hundreds of thousands. Any object storage priced per request wants the same treatment.

A prune ceiling for the same reason: pruning a REMOTE repo repacks, which means downloading
partially used packs and uploading them back, so `--max-repack-size=2G` kept a bad prune from
becoming hours of traffic.

And `--read-data-subset` stayed OUT: rereading means DOWNLOADING, so 10% a day of a ~24 GiB repo
is ~2.4 GiB every day, forever.

### The link is 100 Mb/s, and that was not known

Found on 24/09/2026 while pulling the Arch archive down: `enp7s0` had negotiated **100 Mb/s**,
with an `r8169` (a gigabit Realtek), so rclone at 10.4 MiB/s was already saturating ~87% of the
link. The `restic.md` of 05/08 recorded "23.6 GiB on the wire, 15 min", which is 215 Mbps and
IMPOSSIBLE at 100 Mb/s, so the link degraded somewhere between August and September.

Gigabit needs all 4 pairs of the cable and 100 Mb/s needs 2, so a single broken pair downgrades
the link silently, with no error anywhere. This matters for the next destination: an offsite
restore is capped by this number, and 100 Mb/s turns a 50 GiB restore into ~75 min at best.

## `~/Drive`: a window, not a backup

[`home/services/drive-mount.nix`](../../../home/services/drive-mount.nix) mounts the ROOT of
Google Drive as a local folder (rclone mount plus a VFS cache), so it shows up in Dolphin as a
normal folder. It serves the real case: "sometimes I need a file I do not have here but that is
on the Drive". You see everything right away, with no downloading.

**It is a WINDOW: deleting here deletes there, for real.** It never satisfied rule 6 and it never
will. The `BACKUPS_EX-B560M-V5/**` exclude stays, since the Arch archive still lives there and an
accidental Delete in a repo CORRUPTS it.

### Why a mount and not bisync (decided 05/08/2026)

The first version was `rclone bisync`. It was swapped after LISTING the remote and seeing the
root held real archive (family photos, documents): bisync would download all of it onto the NVMe
to give the same access the mount gives with zero downloading, and a sync PROPAGATES, so deleting
locally would delete on the Drive, family folder included. In a mount every operation is explicit
and singular.

What you lose is OFFLINE access. An accepted trade, since what needed to work offline was the
backup, and that was another module.

### THE MOUNTPOINT HAS TO BE EMPTY

rclone refuses with "…is not empty, use --allow-non-empty to mount anyway", and
`--allow-non-empty` stays OUT on purpose: mounting over an existing file HIDES it, and then you
have invisible data that only reappears when the mount goes down.

It cost the first start (05/08/2026): the bisync version created an `RCLONE_TEST` here, and the
orphaned 0-byte file locked the mount into a restart loop. **If the mount does not come up, check
`ls -a ~/Drive` BEFORE suspecting the network.**

## The CS2 saves, and what they lost

[`home/services/cs2-saves-backup.nix`](../../../home/services/cs2-saves-backup.nix) mirrors the
Cities: Skylines II saves out of `~/.local/share/bottles` (which the backup excluded, ~154 G of
reinstallable Wine prefixes) into `~/CS2-Saves-Backup`. The saves are irreplaceable: a pirated
repack, so no Steam Cloud.

It was HALF of a pair. The mirror put the saves where the daily restic would pick them up, and
that second half is gone. **Today it is an hourly rsync onto the same disk**, which still undoes
an accidental overwrite and is still worth running, but it is not a backup and the module now
says so.

## When the new storage arrives

1. Decide the destination FIRST, and prefer one whose delete is permanent by default or can be
   made so. Re-read the trash section above before trusting any retention setting.
2. Bring back the module and the `restic` toggle. Git still holds the deleted file, with the
   excludes, the `--pack-size=128`, the retention and the prune ceiling already tuned:
   `git log --diff-filter=D --name-only -- system/services/` finds the commit that removed it.
3. Put `~/Drive`, `~/FAI-workstation` and `/mnt/arch-antigo` in `paths`' exclude list on day one,
   or read the FUSE section again the hard way.
4. Give the Arch archive a SECOND copy while you are at it. Right now it has one, on a dying disk.
5. PROVE A RESTORE. Rule 6 has never been tested end to end, and
   [open-items](../../open-items.md) makes that the precondition for impermanence.
