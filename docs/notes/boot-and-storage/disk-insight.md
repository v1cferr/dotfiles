# Disk insight: what grew, and what nobody opens

`home/services/disk-insight.nix`. The trend log, the `/proc` usage sampler and `disk-report`.

## Why the alarm was not enough

`disk-hygiene.nix` is a smoke detector: it speaks below 100 GiB free. MEASURED on 30/08 there were
282 GiB free, so it had never fired once, and a detector that never fires teaches nothing.

Two questions it structurally cannot answer:

- **"What grew?"** It prints the sizes of TODAY. `Downloads` went from 2.5 GiB on 30/07 to 34.9 GiB
  on 30/08 and nothing anywhere recorded that, because nobody was writing the number down.
- **"What do I not use?"** It ranks by size, and size is not the deletion criterion. Diablo IV at
  88.4 GiB and Overwatch at 75.9 GiB look the same in a ranking; one had not been touched in three
  weeks and the other was played that day.

## Why NOT atime, which is the obvious answer

The filesystem already has a "last access" field. It is the wrong source HERE, for two independent
reasons, and both were checked before writing a line of this module.

**`lazytime` does not exist on btrfs.** The original series covered it, but btrfs support was
dropped before the merge over "issues with how btrfs and xfs handle dirty inode tracking". The
mount accepts the option and it silently does nothing, so the cheap version of atime is not on the
table.

**And plain `relatime` is expensive precisely on this machine.** Its documented worst case is a
file whose atime is older than 24 h AND which is snapshotted: the atime update has to CoW the
metadata block shared with the snapshot. That is this setup exactly. btrbk keeps 36 snapshots of
`@home` (`docs/notes/boot-and-storage/btrbk.md`), and `@home` holds 370 GiB of games. Opening
Diablo IV once reads ~88 GiB whose metadata is shared with every one of those snapshots. The
upstream example is 4 GiB with 10 snapshots and one `grep -R` taking metadata from 300 MB to
2.59 GiB.

Turning atime on would have SPENT disk in order to measure disk. That is the whole reason this
module samples processes instead.

## The sampler, and the rule that keeps it honest

Every 10 min it reads `/proc` and asks which watched path has a live process. It writes nothing
into the tree it observes, so there is no CoW and no snapshot divergence.

It also answers a better question than atime would. atime says a file was READ, which an indexer,
a `du` or a backup pass does without the game ever opening. This says the game RAN.

**The evidence rule: `exe` and `cwd` always count, `argv` only for launchers.**

A process cannot be running from a path, or sitting in one, by accident, so those two are proof.
`argv` is only a MENTION. It is still needed, because RPCS3's binary lives in `/nix/store` and the
ISO is an argument, so nothing else would ever see `~/Games/PS3`. Trusting it everywhere is what
breaks: any shell that so much as types the path would look like a game session, and this note's
own author tripped that while testing.

`usageIgnoreCommands` is the backstop for the sweepers that walk these paths BY DEFINITION. The one
that matters is `cs2-saves-backup`: it rsyncs out of the CS2 bottle every hour, with the path in
argv, which would have marked Cities Skylines II as played forever.

**GAME granularity, not bucket.** `usagePaths` points at Diablo IV and Overwatch separately, never
at `bottles` as a whole. A bucket is "used" the moment ANY game inside it opens, which is exactly
the resolution that hides the one nobody has touched.

## What it cannot tell you

It only counts FROM THE DAY IT WAS INSTALLED. There is no history to recover, same as atime would
have had. A path reading "not once since sampling began" one week in means one week, not never.

A shell sitting inside a game folder counts as use. That is deliberate: a human is in there.

## The trend log

Append-only, `Sun 05:30`, one line per path per run, after restic, `nix-optimise` and the docker
prune so they are not fighting over the same NVMe. `disk-report` diffs the last two entries.

Append-only for the same reason the history folder is (`docs/README.md`): a series that gets
rewritten stops being evidence of what happened.

## Why the state is not in `~/.cache`

`~/.cache` is disposable by definition, and restic excludes it. The "last used" table is the one
thing here that CANNOT be recomputed after the fact, so it lives in `$XDG_STATE_HOME`, which the
backup does cover.
