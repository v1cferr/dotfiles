# Disk health (smartd)

Module: [`modules/nixos/hardware/smartd.nix`](../../../modules/nixos/hardware/smartd.nix), plus the
Seagate's own lines in [`hosts/ex-b560m-v5/hardware.nix`](../../../hosts/ex-b560m-v5/hardware.nix).

Every disk is watched (`DEVICESCAN`), and an alarm goes out through `my.alert`, the same journal
plus critical bubble the btrfs scrub and the backup use. The module's own channels are off: there is
no mailer on this machine, and `wall` and `xmessage` reach nobody on a Wayland session.

## What fires, and what does not

`-a` fires on what predicts data loss: the health verdict turning FAILED, a prefailure attribute
crossing its threshold, a new entry in the error or self-test log, and any count of pending or
offline-uncorrectable sectors. It does NOT fire on an attribute merely moving, so a worn disk does
not alarm every half hour for being worn.

`-n standby,q` means smartd never spins a sleeping disk up to look at it, which matters for the
Seagate, spun down most of the day.

**No temperature alarm on the NVMe.** The Kingston's reported peak sits pinned at its TMT1 of
76 C, which reads as a heat problem and is not one. `-W` is set only on the Seagate.

## The Seagate, MEASURED on 03/10/2026

A Momentus 7200.4 laptop disk from 2009, now the backup's home
([decision 0011](../../decisions/0011-local-disk-backup.md)):

| Attribute | Value | Reading |
| --- | ---: | --- |
| Reallocated, Pending, Offline Uncorrectable, Reported Uncorrect | 0 | the media is clean |
| SMART error log | empty | |
| UDMA CRC errors | 348 | the same count as months ago, and 0 ICRC in this boot's SATA PHY log: old cabling, not now |
| Load Cycle Count | 850,316 | ~1.4x the spec, normalized 001; it was ~840k when last noted |
| Head flying hours | ~37,800 | |
| Lifetime max temperature | 59 C | over the 43 C spec at some point; 36 C now |

The verdict: the media is healthy and the MECHANICS are worn, so the likely failure is sudden (heads,
ramp) rather than a slow rot of sectors. That is acceptable for a backup, whose loss is the backup
and not the data, as long as the loss is SEEN. Hence the extra lines for this one disk:

- **APM 254 and a 30-minute standby** (`hdparm -B 254 -S 241`, a udev rule keyed on the serial). APM
  128 parked the heads every few idle seconds, which is where the 850k came from; now they stay
  loaded while it spins, and it spins down when nobody uses it.
- **`-W 4,45,50`**: logs a 4 C jump, alarms at 45 C and at 50 C.
- **Self-tests**: short every Sunday at 04:00, long on the 1st of each month at 05:00.
