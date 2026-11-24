# Power loss: what survives a cut, and the report after one

`modules/nixos/hardware/power-loss.nix`. The desk has no UPS yet, so a knocked cable or a power
outage cuts it with no shutdown at all. This page is what each layer does about it, the alarm
that says what recovered, and the checklist after one.

## The 2026-11-24 cut, layer by layer

A knocked power strip at 13:43:52. The journal stops mid Chromium activity and `last -x` says
`crash`. The 13:45 boot recovered with no help:

| Layer                | What the boot log showed                               | Verdict                           |
| -------------------- | ------------------------------------------------------ | --------------------------------- |
| btrfs root           | `start tree-log replay`, then a normal mount           | OK: CoW plus the log tree held    |
| ESP (vfat, `/boot`)  | fsck cleared the dirty bit; boot sector differs at 65  | Harmless (offset 65 is that flag) |
| journald             | `system.journal corrupted or uncleanly shut down`      | Rotated; up to 5 min never synced |
| PostgreSQL           | `automatic recovery in progress`, WAL redo, checkpoint | OK: that is what the WAL is for   |
| ntfs3 (Windows disk) | `Correct links count -> 2` on one inode                | Run chkdsk from Windows           |
| systemd units        | none failed                                            | OK                                |

Nothing was lost that a backup had to bring back. What a cut CAN take: unsaved editor buffers,
the last seconds of writes still in the page cache, and the open Chromium session state.

## What already protects each layer

- **btrfs** never overwrites live data (CoW) and replays its log tree on the next mount, so the
  FS is consistent after a cut. Write barriers stay on (the default; turning them off is how a
  cut corrupts btrfs). The monthly scrub and the daily `device stats` alarm
  ([btrfs](../boot-and-storage/btrfs.md)) catch damage a cut could leave behind.
- **Snapshots and backup**: btrbk every hour on `/home` ([btrbk](../boot-and-storage/btrbk.md))
  and restic to the Seagate every night ([restic](../boot-and-storage/restic.md)).
- **Postgres** replays its WAL. Never turn off `fsync` or `full_page_writes` for speed.
- **ntfs3** refuses a dirty volume, and `windows-disk-clear-dirty` only clears a flag
  `ntfs-3g.probe` calls safe ([games-disk](../boot-and-storage/games-disk.md)). ntfs3 fixes
  little things itself, but only Windows' chkdsk really checks NTFS.
- **journald** syncs every minute (`SyncIntervalSec=1m` in `modules/nixos/core/core.nix`, the
  default is 5 min), so a cut loses at most the last minute of log.
- **VS Code** saves a second after each edit (`files.autoSave`). `hotExit` alone only covers a
  window closed on purpose.

## The report

A marker file tells a clean shutdown from a cut:

1. `power-loss-marker.service` runs early in every boot. If `/var/lib/power-loss/running` is
   still there, the last boot never reached its clean stop, so it copies the marker to
   `pending`. Then it writes a new marker.
2. Its `ExecStop` deletes the marker. systemd only runs it on a real shutdown or reboot, so a
   cut leaves the marker behind. That is more reliable than parsing `last`.
3. `power-loss-report.timer` fires 5 minutes into the boot. By then every recovery has run (a
   container Postgres took 2 minutes on 24/11) and the autologin session can get the bubble.
   When `pending` exists it collects the evidence, writes `/var/lib/power-loss/last-report` and
   sends one `my.alert`.

What it collects: when the previous boot last logged, a btrfs log replay and any btrfs error,
ntfs3 corrections, the ESP fsck, Postgres crash recoveries (native and in containers, they all
log to the journal), failed units, and the NVMe `Unsafe Shutdowns` counter. The report keeps that
counter on every boot, so the alarm shows how much THIS incident added. If the counter grows on
CLEAN boots too, the drive is being cut at shutdown, and that is worth investigating on its own.

The first boot after the module lands has no marker, so it reports nothing.

To read the last report: `sudo cat /var/lib/power-loss/last-report`.

## After a cut: the checklist

1. Read the alarm. If everything says clean or OK, stop here.
2. Any btrfs error: `sudo btrfs device stats /` and `sudo btrfs scrub start -B /`.
3. Any ntfs3 correction: boot Windows and run `chkdsk D: /f` (the games disk) before trusting
   the disk again.
4. Any failed unit: `systemctl status <unit>`. A container whose volume is NOCOW
   (`/var/lib/docker/volumes`) has no btrfs checksums, so its own recovery is the only check.
5. Confirm the backup is fresh: `systemctl status backup-staleness`.

## UPS (planned purchase)

The real fix: a UPS rides through short cuts, and on a long one NUT shuts the PC down cleanly
before the battery runs out. It also covers a knocked power strip, as long as the strip feeds the
UPS and not the PC directly. Not bought yet (money); this is the shortlist so the purchase is
quick. No NUT code goes in the repo before the hardware exists (zero legacy).

### Requirements

| Requirement      | Why                                                                                     |
| ---------------- | --------------------------------------------------------------------------------------- |
| Pure sine output | the PSU has active PFC, and a stepped wave can make it drop or buzz on battery          |
| Line-interactive | the AVR handles sags without touching the battery; online double conversion is overkill |
| 1200 to 1500 VA  | sized below; a few minutes at gaming load, much longer idle                             |
| USB, NUT driver  | the whole point is the clean shutdown; a vendor-only Windows app is useless here        |
| RJ45 in/out      | surge protection for the modem-to-router cable (a wish, see below)                      |
| 127 V or bivolt  | the house outlets                                                                       |

**Sizing.** Measured (`power-log`, [baseline](power-and-memory-baseline.md)): the Arc idles at
45 W and drew 86 W in Hearthstone with a 60 W CPU package. The ceilings are the B580's 190 W board
power and the i5-11400's 154 W turbo, so the whole box tops out around 350 W, plus about 30 to
40 W per monitor if they go on the UPS too. A 1500 VA / ~900 W unit runs at under half load even
in the worst case, which keeps the runtime useful and the inverter cool. The router and the modem
(about 15 W together) go on it as well, so the internet survives the cut.

**About the RJ45 port.** On a home UPS it is a pass-through with surge protection: the cable from
the modem goes in, out to the router, and a spike on the line dies in the UPS instead of the
router. It does NOT put the UPS on the network. Network management (an SNMP card) is an
enterprise add-on, and here USB plus NUT already does that job (and NUT can serve the status to
other machines over the network if that is ever wanted).

### Candidates and their NUT support

NUT's own list (`data/driver.list.in` on the NUT repo, read on 24/11/2026) rates support from 1
star (reverse engineered) to 5 (vendor protocol and hardware):

| Brand and line                | NUT driver   | Stars | Notes                                                              |
| ----------------------------- | ------------ | ----- | ------------------------------------------------------------------ |
| TS Shara (various, e.g. XPro) | `nutdrv_qx`  | 4     | the vendor gave the protocol; the best fit among Brazilian brands  |
| APC Back-UPS BR/BZ (Microsol) | `solis`      | 2     | the Brazilian APC line is Microsol hardware, NOT `usbhid-ups`      |
| APC SMC (Smart-UPS, BR)       | `usbhid-ups` | 3     | solid, but a Smart-UPS costs far more than the need                |
| Ragtech Easy (TI/M2)          | `ragtech`    | 1     | experimental driver                                                |
| Intelbras SNB/DNB             | `nutdrv_qx`? | none  | not on the list; users report Megatec Q1 with wrong battery values |
| SMS (Manager, Gamer)          | unknown      | none  | not on the list; vendor app only                                   |

Before buying: confirm the exact model has pure sine output, the RJ45 pair, and either a TS Shara
`nutdrv_qx` entry or a user report of it working with NUT. Check NUT's issue tracker for the model
name.

### The plan when it arrives

1. `lsusb` for the vendor and product ID, then `nut-scanner -U` to confirm the driver.
2. A NUT module in standalone mode (`power.ups`): the driver, `upsmon` shutting down on low battery,
   and `offdelay` so the UPS cuts its outputs after the PC is down.
3. With the BIOS on Last State, the PC stays off after a NUT shutdown and comes back after an
   accidental unplug.
4. Test it for real: pull the UPS from the wall with the PC idle and watch `upsc` until the
   shutdown.

## The BIOS side

The board's *Restore AC Power Loss* decides whether the PC comes back by itself. It is firmware,
so it is not declared here; the choice (Last State) and why are in the
[BIOS guide](../../guides/bios-ex-b560m-v5.md#restore-ac-power-loss).
