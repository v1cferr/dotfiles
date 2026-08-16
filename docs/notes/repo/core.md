# core

Module: [`system/core/core.nix`](../../../system/core/core.nix)

Nix and flakes, the ceilings on disk growth, nix-ld and the locale. Everything here is about
keeping something from growing without bound.

## Store dedup is SCHEDULED, not automatic

`nix.optimise` with a date, and not `auto-optimise-store`. That one runs the hardlinking on EVERY
build, and on btrfs the metadata churn is CoW, which gets expensive on a machine that rebuilds all
day. Scheduled, the work leaves the critical path and goes into an idle window (03:45, away from
the weekly GC and the daily restic).

It is NOT because of the fear that circulates, "auto-optimise corrupts the store": the
NixOS/nix#7273 race was fixed, and the assert that claims otherwise is nix-darwin policy. The
reason is only WHEN the work happens.

## Two garbage collectors would be one too many

`programs.nh.clean` is OFF on purpose. It brings up a timer for `nh clean all`, and the GC already
has an owner: `nix.gc` (weekly, 30d) plus the space-reactive one below.

Two collectors on the same store is exactly rule 14's "two owners for the same artifact". Neither
fails, and the real retention becomes the INTERSECTION of the two policies, which is to say you
think you have 30 days of rollback and you have whatever the other one left. If nh's is ever
preferred, turn `nix.gc` OFF in the same commit.

## The space-reactive GC, and why 15/50 and not 1/5

If free space drops below `min-free` during a build, Nix collects until it frees `max-free` and
the build goes on, which avoids "no space left" in the middle of a big rebuild.

Raised from 1 GiB/5 GiB on 30/07. **1 GiB is TOO LATE to be a safety net**: starting to collect
only when 1 GiB is left is arriving after the accident, and the build that triggered the
collection has probably already failed. Here the partition is SHARED with games and media
(measured: 506 GiB across Bottles/Jellyfin/Steam against 58 GiB of store), so the space can
disappear outside Nix and Nix needs real slack. A 15 GiB floor gives room for a big rebuild; a
50 GiB target avoids collecting again on the next build.

**The names matter**: in this Nix (2.34.8) they are `min-free`/`max-free`. The rename to
`gc-threshold`/`gc-limit` plus `auto-gc` belongs to a newer version and does NOT exist here
(checked with `nix config show`).

## The journal's ceiling

Without `SystemMaxUse`, journald uses its default: 10% of the filesystem. On this machine (915 G)
that is **~92 GiB it can occupy LEGITIMATELY**, with nothing raising a flag, which is the kind of
growth you only discover with a full disk.

Today it sits at 530 MiB, so 2 GiB is a roomy ceiling that still keeps weeks of history. The
concrete lesson behind it, from 30/07: two timers of mine wrote 2148 lines/DAY before they got
`LogLevelMax`. `SystemMaxFileSize` caps each file so the rotation is gradual instead of in 1/8
steps.

## Why nh replaced nixos-rebuild in the aliases

`nh os switch` adds two things `nixos-rebuild` does not give:

- a progress TREE for the build (nix-output-monitor inside) instead of the wall of
  `building '/nix/store/…'` that does not say what is left;
- a package DIFF between the current generation and the new one: what went up a version, what came
  in, what went out. That is information I once spent a whole day extracting by hand comparing
  store paths.

`--ask` is opt-in (checked in `--help`), so it does NOT become interactive: it stays safe over SSH
and inside a script, which matters on this remote-access machine.

## The daemon runs at idle priority

Builds max out the cores compiling, and yielding CPU and disk to the interactive session is what
keeps a rebuild from freezing the desktop or the Moonlight stream. With the machine idle the build
uses everything normally, because idle only yields when something else wants it.

## Locale

The system is `en_US.UTF-8` by preference: output and errors in English make debugging easier.
`pt_BR.UTF-8` is generated too, and the only consumer is the lockscreen's clock, which reads
`LC_TIME` for the spelled-out date. That is the pt-BR exception rule 17 names. The timezone and
the TTY keymap follow BR, because those are physical facts.
