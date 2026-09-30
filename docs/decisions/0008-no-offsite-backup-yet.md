# 0008. No offsite backup, for now

The machine has no copy outside itself since 24/09/2026, and waiting for storage is a risk taken knowingly.

- **Status**: accepted risk, review by 2026-12-31
- **Date**: 30/09/2026

## Context

The 3-2-1 rule asks for three copies, on two kinds of media, one of them offsite. Today there is
one copy plus btrbk's hourly snapshots of `@home`, which live on the same NVMe and so cover an
accidental overwrite and nothing else. The daily restic to Google Drive was retired on 24/09/2026
when its quota filled (the whole account is in
[open-items](../open-items.md) and [restic](../notes/boot-and-storage/restic.md)).

## Decision

No new destination yet. The three compared on 30/09/2026, so the next decision starts from here:

| Destination | Cost, as quoted by third-party guides that day (NOT checked on the providers' own pages) | What it covers |
| --- | --- | --- |
| Hetzner Storage Box | about 3.20 EUR a month for 1 TB, SFTP, no egress fee | offsite, and restic speaks SFTP natively |
| Backblaze B2 | about 6 USD per TB a month, 10 GB free, free egress up to 3x stored | offsite, paid by use |
| a local USB disk | the disk, once | a dead NVMe; not a theft, a fire or a surge |

## Consequences

- A dead NVMe, a theft or a fire loses everything in `~` that is not in git.
- The Arch archive is ONE copy on a 2009 disk already showing errors; giving it a second copy is
  part of closing this, not a separate task.
- The link runs at 100 Mb/s over a damaged cable, which caps any offsite restore: worth fixing
  before choosing a remote destination.
