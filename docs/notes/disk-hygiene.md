# Disk hygiene: a space alarm plus trash expiry

`home/services/disk-hygiene.nix`.

## Why this exists, and why it is NOT more GC

The Nix GC is already automatic (`system/core/core.nix`) and it works, but MEASURED on 30/07 it
covers **9% of the disk**: `/nix/store` held 58 GiB against 626 GiB used.

The other 91% is games and media (Bottles 319 GiB, Jellyfin 132, Games 47, Steam 8), and NONE of
that can be deleted automatically. Nobody should delete somebody's game on their own.

So the right answer to "do not let the disk fill up" is not deleting more, it is WARNING with
enough data for me to decide.

## Two things of different natures, together

They are the same task (keeping the disk under control) and both are user timers.

- **`disk-watch`**, the alarm: it notifies when free space drops, ALREADY WITH the biggest
  consumers in the message. The request was "to evaluate what I want to remove", and for that the
  notification has to say WHAT grew.
- **`trash-expire`**: the trash was the only REAL garbage found in the measurement, 1.7 GiB sitting
  there that nobody expired and that restic already excludes from the backup, so it was pure waste.

## The two-phase design

`du` over the whole tree takes MINUTES on this machine, measured. Running that every 30 min would
be absurd.

So the timer only does the CHEAP check (`df`, instant), and the EXPENSIVE sweep only happens when
the disk is actually low, which is the moment when spending a few minutes is exactly what you want.
`nice` plus `ionice` so it does not compete with the session.

## Anti-spam

A notification repeating every 30 min becomes noise and starts being ignored, the same mistake as
the timers that drowned the journal (see bb8690c). It re-warns at most once every 12 h per
severity, but IMMEDIATELY if the severity goes up (warn to crit). The state lives in
`$XDG_RUNTIME_DIR`, which resets at boot.

`LogLevelMax = "warning"` on both units for the same reason: the scripts already exit silently, but
that cuts the "Starting…/Finished…" SYSTEMD logs on its own, which is where those 2148 lines/day
came from.

## The owner (rule 15)

A `systemd --user` timer tied to `graphical-session`, because it needs the session: what delivers
the notification is Quickshell, the `org.freedesktop.Notifications` daemon.

## The panel

**100/40 GiB and not a percentage**: what matters is whether the NEXT game or patch fits, and that
is an absolute number. There are 915 G in total here; on 30/07 there were 243 GiB free, so 100
warns with real room to decide.

`watchPaths` holds the weights measured on 30/07, from largest to smallest. It is deliberately NOT
a full `du /`: sweeping everything would take extra minutes and bring noise (`/proc`, `/sys`,
network mounts). If a new consumer shows up outside this list, it is 1 line, and filelight and
czkawka exist precisely to discover it.

| Path | Measured 30/07 |
| --- | --- |
| `~/.local/share/bottles` | 319 GiB (Battle.net, CS-II, Ascension) |
| `/srv/media` | 132 GiB, the Jellyfin library |
| `/nix/store` | 58 GiB, handled by the GC, not deletable by hand |
| `~/Games` | 47 GiB |
| `~/.local/share/Steam` | 8 GiB |
| `~/.cache` | 3.9 GiB |
| `~/Downloads` | 2.5 GiB |
| `~/.local/share/Trash` | 1.7 GiB, expired by the timer below |

## Small script details

- `df --output=avail -BG` comes out as `"  123G"`, so strip the G and the space. If `df` fails
  (the fs disappeared?), exit rather than invent an alarm.
- The sweep uses MiB so it can be sorted numerically, and the output is formatted in GiB. The
  `|| true` is there because a nonexistent path or one without permission cannot take the alarm
  down.
- `trash-empty -f`: the default only asks with `-i`, but in a timer it is better to be explicit,
  since a unit waiting for an answer hangs forever.
