# Disk hygiene: a space alarm plus trash expiry

`home/services/disk-hygiene.nix`.

## Why this exists, and why it is NOT more GC

The Nix GC is already automatic (`system/core/core.nix`) and it works, but MEASURED on 30/07 it
covers **9% of the disk**: `/nix/store` held 58 GiB against 626 GiB used. REMEASURED on 30/08 the
GC had done its job on its own, taking the store down to 46 GiB, and the share it covers fell to
**7% of 664 GiB used**.

The other 93% is games and media, and NONE of that can be deleted automatically. Nobody should
delete somebody's game on their own.

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

**Absolute GiB and not a percentage**: what matters is whether the NEXT game or patch fits, and
that is an absolute number.

**150 and no longer 100.** The original 100 was set when 243 GiB were free and the reasoning was
"room to decide". What changed is the size of one decision: the biggest single consumer here is now
an ~88 GiB game, so 100 GiB free is barely one install of headroom. A warning that arrives with
room for exactly one more thing is not a choice, it is a notice.

`watchPaths` is deliberately NOT a full `du /`: sweeping everything would take extra minutes and
bring noise (`/proc`, `/sys`, network mounts). If a new consumer shows up outside this list, it is
1 line, and filelight and czkawka exist precisely to discover it.

### The list drifted, which is the lesson

The 30/07 list was a month old and already lying. `/srv/media` was off by 3x, and `~/.config` had
become the 4th biggest consumer on the machine without ever being on the list, so the alarm was
structurally blind to 27 GiB. A hardcoded ranking rots; that is why `disk-insight.nix` logs a trend
instead of trusting a snapshot.

| Path | 30/07 | 30/08 |
| --- | --- | --- |
| `~/.local/share/bottles` | 319 GiB | 316 GiB (Battlenet 181, CS-II 85, Ascension 46) |
| `~/Games` | 47 GiB | 46 GiB (one 46 GiB PS3 ISO) |
| `/nix/store` | 58 GiB | 46 GiB, handled by the GC, not deletable by hand |
| `/srv/media` | 132 GiB | 45 GiB, the Jellyfin library |
| `~/Downloads` | 2.5 GiB | **35 GiB** |
| `~/.config` | not listed | **27 GiB** (Claude `vm_bundles` 14, Chrome 6) |
| `~/Projects` | not listed | 18 GiB |
| `~/.cache` | 3.9 GiB | 9 GiB |
| `~/.local/share/Steam` | 8 GiB | 8 GiB |
| `~/Documents` | not listed | 4.5 GiB |
| `~/.local/share/Trash` | 1.7 GiB | 0.1 GiB, the timer below is working |

### It names the FILES too

A directory ranking answers WHERE and stops there. MEASURED on 30/08: `~/Downloads` showed up at
35 GiB and 17.4 of those were a single `world.rar`. The folder is never the thing you delete, so
the alarm lists the biggest individual files under it.

The `find` only runs in phase 2, for the same reason the `du` does: it is minutes of work that is
only worth spending once the disk is actually short.

## Small script details

- `df --output=avail -BG` comes out as `"  123G"`, so strip the G and the space. If `df` fails
  (the fs disappeared?), exit rather than invent an alarm.
- The sweep uses MiB so it can be sorted numerically, and the output is formatted in GiB. The
  `|| true` is there because a nonexistent path or one without permission cannot take the alarm
  down.
- The awk splits on `-F'\t'` and NOT on whitespace. `du` separates with a tab, and every Windows
  game path has spaces in it, so the default split silently truncates the name at the first one.
- `trash-empty -f`: the default only asks with `-i`, but in a timer it is better to be explicit,
  since a unit waiting for an answer hangs forever.
