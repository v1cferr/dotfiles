# Docker's prune policy

`system/services/docker.nix`. This module does NOT turn the engine on.

## Why it is a separate module with no toggle of its own

What turns the engine on are the stacks (`duo.nix`, `grad-radar.nix`), each with its own
`virtualisation.docker.enable = true`. Pruning is the MACHINE's concern, not a stack's: either of
the two may have brought the daemon up, and the garbage that piles up belongs to the daemon, not
to them. So the `mkIf` looks at the engine's state instead of a toggle: turn docker on by any
path and you get pruning; with no stack on, this module does nothing.

## The measured problem (10/08/2026)

Docker was the machine's only growth with NO ceiling:

```text
Build Cache   287 entries   11.35 GB   RECLAIMABLE: 8.545 GB
```

Nothing pruned that. No timer, no policy, and the cache only grows. Compare with the neighbors,
which all DO have a ceiling: journald at `SystemMaxUse=2G`, coredumps vacuumed by systemd, btrbk
with `snapshot_preserve`, nix with a weekly `gc`.

And `grad-radar.nix` made it worse the same day it came in: it runs `docker compose build` in the
`ExecStartPre`, which is to say ON EVERY BOOT. With no pruning the cache gains a new layer every
time the machine turns on.

## The two options that look "more complete" and destroy data

Both fail in the SAME window: the stack STOPPED at pruning time. Neither errors out; they
successfully delete what they should not.

**`autoPrune.allVolumes.enable`: NEVER.** It prunes a NAMED volume, not just an anonymous one, and
that is where the databases live: `duo_duo-db-data`, `duo_duo-data`, `grad-radar_db_data` (checked
with `docker volume ls`). With the compose down (a reboot, a manual `down`, a failing
`ConditionPathExists`), the weekly prune deletes both projects' Postgres. The option's name
suggests "clean more"; the effect is silent data loss. The default, anonymous only, is the right
one.

**`flags = [ "--all" ]`: refused**, even though it is what most public configs use. `--all` removes
a TAGGED image that is not in use by a RUNNING container. The local images (`duo-web`, `duo-api`,
`duo-daemon`, `grad-radar-backend`) do not come from a registry: gone means a rebuild, and in
grad-radar the rebuild includes a `pnpm install` INSIDE the container, which is why that unit has
`TimeoutStartSec = 1800`. Trading minutes of boot for a few GB does not pay, all the more because
`prune` without `--all` already takes what matters here: the dangling build cache, dangling
images, stopped containers and orphaned networks.

## The schedule

`Mon 04:30`, not systemd's `weekly` (which is Mon 00:00, EXACTLY nix-gc's time in
`system/core/core.nix`). Two I/O-heavy cleanups in the same minute on the same NVMe, with no gain
in putting them together. 04:30 falls after restic (03:00 plus up to 30 min of random delay) and
after nix-optimise (03:45), so the small-hours window becomes a queue instead of a fight.

`persistent` already comes `true` from the module and is NOT redeclared, but it matters here: this
machine spends nights turned off, so a weekly small-hours timer without it would simply never run.

## Checking before you trust it

```sh
docker system df -v    # the weight item by item (image, container, cache)
docker system prune    # WITHOUT -f: it lists the categories and asks y/N, and N is the preview
```

There is no `--dry-run` (checked in Docker 29.6.2's `--help`); the confirmation is what there is.
