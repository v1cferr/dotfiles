# Arch Linux legacy

A CLOSED chapter. It stays here because the archive still exists, and a repo nobody knows
how to open is worse than a repo that was deleted.

> These are my legacy Arch Linux configs, which we are migrating entirely to Nix and NixOS
> so that everything is declarative instead of manual, and so that it works on any hardware
> later on.

Closed on 05/08/2026. The Kingston was formatted (01/08), the module that created the
backups was deleted, the manual `~/BACKUP-KINGSTON` copy was deleted and the local leg
(Seagate) went away. What is left is **the offsite copy only**, which passed
`check --read-data` (189 packs, 0 errors).

This pointer survives because a repo nobody knows how to open is worse than a repo that was
deleted:

The folder on the Drive was renamed from `KINGSTON` to **`ARCH-KINGSTON`** on 05/08/2026
(the old name did not say it was the Arch one).

**There is no command to run**: since 11/08/2026 the archive stays mounted at
`/mnt/arch-antigo` from login on, so it is just a matter of opening the **Arch antigo**
bookmark in Dolphin. What mounts it is the user unit `arch-antigo-mount`
([`home/services/arch-legacy-mount.nix`](../home/services/arch-legacy-mount.nix)); the
mountpoint and the SSOT of the path belong to the system side
([`system/services/arch-legacy.nix`](../system/services/arch-legacy.nix)). The
`arch-browse` alias died along with it, and an empty folder here became a symptom rather
than a normal state:

```bash
systemctl --user status arch-antigo-mount   # empty folder? the diagnosis starts here
systemctl --user restart arch-antigo-mount  # zombie mount after the network dropped
```

Turn **previews** (thumbnails) off in Dolphin before browsing in here: a preview reads
the CONTENT, and every read makes restic download packs from the Drive. Measured: a 3.9 MiB
folder cost 3.68 MiB of download in icons alone (see the TODO from 07/08/2026). With the
permanent mount that got more important, not less, because the folder is always one click
away.

The mount runs as the USER on purpose: a FUSE mount is private to whoever mounted it, so
`sudo restic mount` produces a folder the file manager cannot open. The Arch dotfiles are at
`home/v1cferr/dotfiles` inside the snapshot (`6d7e3ee7`, 44.6 GiB). Both secrets are still
declared on purpose: they are the KEY to the archive, not leftovers from the module.

- Repo on GitHub: <https://github.com/v1cferr/dotfiles>
