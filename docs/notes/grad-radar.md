# GradRadar: the stack at boot and the monitor on a timer

`system/services/grad-radar.nix`. The app stack (Next.js + FastAPI + Postgres) comes up at BOOT,
and the call-for-applications chain runs on a timer: collect, re-evaluate the schedule, notify.

## The problem this solves

Caddy already came up on its own and so did Docker, but the grad-radar containers did not. After
every reboot `https://pos.v1cferr.dev` answered 502, the proxy up with no upstream, until somebody
ran `just dev` by hand. A link that only works when the owner is sitting in front of the PC is no
good for sending to other people.

## Why systemd and not `restart: unless-stopped`

The dev compose declares `restart: "no"` on purpose: containers that resurrect on their own after
a daemon restart become orphans running with nobody asking. A `oneshot` with `RemainAfterExit`
gives the boot behavior without bringing that back, since what orders the start is the boot, not
dockerd.

## Why the working-tree path and not a store path

Unlike `duo.nix`, which consumes a flake input at a fixed commit, this one points at the
repository where development happens. It is a conscious choice with a cost: what is live is the
commit on disk, not one pinned in `flake.lock`. In exchange, `just dev` and the service are THE
SAME stack (same project name via `-p grad-radar`, same ports, same volumes), so they do not fight
over 3006/8006 and there are not two copies diverging. As long as the project is edited every
week that is the right trade; when it settles down, it becomes a flake input.

Nix never reads the path at evaluation time, so the impurity stays contained in the systemd unit
and does not contaminate the flake. `ConditionPathExists` makes the unit be SKIPPED when the clone
does not exist (a new host), instead of failing: a red service caused by a missing clone trains
you to ignore red services.

## It is a development server exposed to the world

The frontend runs `next dev`, not `next build && next start`: it recompiles on demand, spends more
memory and is much slower on the first hit. For three people checking a deadline, it serves. If it
becomes something more, the step is a production compose, not touching this one.

## The Docker traps, inherited from duo.nix

- `after = docker.service` is not enough when dockerd comes up through socket activation and the
  API is not answering yet, hence the wait-for-`docker info` loop.
- Root does not DISCOVER buildx without a writable `DOCKER_CONFIG` with the plugins linked in, and
  the build silently falls back to the legacy builder.
- `TimeoutStartSec = 1800` because the first start builds two images and the frontend's
  `pnpm install` runs inside the container.

## The monitor chain, and why that order

Up to here the collector only ran when somebody typed `just monitor`. A monitor that depends on
somebody remembering to run it is not a monitor, it is exactly the failure the project exists to
avoid, only with more steps.

1. `monitor --quiet`: only a change or a failure becomes a log. A journal with 19 lines of "the
   same" per hour is a journal nobody reads.
2. `verify` runs after and WITHOUT `--apply`: it rereads the schedules just downloaded and
   compares the verdict against the database. Reporting and not writing is deliberate, since a
   divergence can be a new schedule (what you want to know) or the extractor failing on an unseen
   format, and writing silently would erase the difference. A person decides, with
   `just verify-apply`.
3. `notify` last, because it reads what the two before it just wrote. Running it first would warn
   about the PREVIOUS run's state, and an alert a day late is worse than none in a project whose
   enemy is precisely finding out too late. With no channel configured it only RECORDS the events,
   it does not fail: the chain should not break for lack of a credential.

## The timer

`08:00,20:00`. Calls for applications do not change hour by hour, and the only window that matters
lasts weeks; checking more would be load on UFSCar with no gain. `Persistent = true` because the
machine is a desktop and spends nights turned off, and without it a missed check disappears
forever, which is precisely the project's failure mode.
