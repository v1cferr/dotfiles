# ═══════════════════════════════════════════════════════════════════════════
# DOCKER: the automatic PRUNE policy. This module does not turn the engine on.
#
# WHAT TURNS THE ENGINE ON are the stacks (./duo.nix, ./grad-radar.nix), each with its own
# `virtualisation.docker.enable = true`. Pruning is the MACHINE's concern, not a stack's: either
# of the two may have been the one that brought the daemon up, and the garbage that piles up
# belongs to the daemon, not to them. That is why the `mkIf` looks at the engine's state instead
# of a toggle of its own: turn docker on by any path and you get pruning; with no stack on, this
# module does nothing.
#
# THE MEASURED PROBLEM (10/08/2026), which is the machine's only growth with NO CEILING:
#
#     Build Cache   287 entries   11.35 GB   RECLAIMABLE: 8.545 GB
#
# Nothing pruned that: there is no timer, there is no policy, and the cache only grows. Compare it
# with the neighbors, which DO have a ceiling: journald is at `SystemMaxUse=2G`, coredumps are
# vacuumed by systemd, btrbk has `snapshot_preserve`, nix has a weekly `gc`.
# Docker was the only one with nothing.
# And ./grad-radar.nix MADE IT WORSE the same day it came in: it runs `docker compose build` in
# the ExecStartPre, which is to say ON EVERY BOOT. With no pruning, the cache gains a new layer
# every time the machine turns on.
#
# ── THE TWO OPTIONS THAT LOOK "MORE COMPLETE" AND DESTROY DATA ──────────────
# Both fail in the SAME window: the stack STOPPED at pruning time. Neither one errors out; they
# successfully delete what they should not.
#
# `autoPrune.allVolumes.enable`: NEVER. It prunes a NAMED volume, not just an anonymous one, and
# that is where the databases live: `duo_duo-db-data`, `duo_duo-data`, `grad-radar_db_data`
# (checked with `docker volume ls`). With the compose down (a reboot, a manual `down`, a failing
# ConditionPathExists), the weekly prune deletes both projects' Postgres. The option's name
# suggests "clean more"; the effect is silent data loss. The default (anonymous only) is the right
# one and it stays as it is.
#
# `flags = [ "--all" ]`: refused, even though it is what most public configs use. `--all` removes
# a TAGGED image that is not in use by a RUNNING container. The local images (duo-web, duo-api,
# duo-daemon, grad-radar-backend) do not come from a registry: gone means a rebuild. In grad-radar
# the rebuild includes a `pnpm install` INSIDE the container, which is why the unit has
# `TimeoutStartSec = 1800`. Trading minutes of boot for a few GB does not pay, all the more
# because `prune` without `--all` already takes what matters here: the dangling build cache,
# dangling images, stopped containers and orphaned networks.
#
# CHECK what the prune is going to take BEFORE trusting it:
#   docker system df -v    # the weight item by item (image, container, cache)
#   docker system prune    # WITHOUT the -f: it lists the categories and asks y/N, and answering
#                          # N is the preview. There is NO `--dry-run` (checked in Docker
#                          # 29.6.2's --help); the confirmation is what there is.
# ═══════════════════════════════════════════════════════════════════════════
{ config, lib, ... }:

lib.mkIf config.virtualisation.docker.enable {
  virtualisation.docker.autoPrune = {
    enable = true;

    # systemd's `weekly` = Mon 00:00, which is EXACTLY nix-gc's time (system/core/core.nix). Two
    # I/O-heavy cleanups in the same minute, on the same NVMe, with no gain at all in putting them
    # together. 04:30 falls after restic (03:00 plus up to 30 min of random delay) and after
    # nix-optimise (03:45), so the small-hours window becomes a queue instead of a fight.
    dates = "Mon 04:30";

    # `persistent` already comes `true` from the module, and here that is NOT a detail: this
    # machine spends nights turned off, so a weekly small-hours timer with no persistence would
    # simply never run. Not redeclared on purpose, since the default is already right.
  };
}
