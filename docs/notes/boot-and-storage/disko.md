# disko (nixos-kingston)

Module: [`hosts/nixos-kingston/disko.nix`](../../../hosts/nixos-kingston/disko.nix)

The declarative disk layout for the KINGSTON KC3000 (NVMe Gen4).

## It is destructive, and it has already run

It wipes the whole disk. It does NOT run on a normal rebuild, only on the CUTOVER, which HAPPENED
on 01/08/2026. The Arch that lived here was archived to Google Drive before that, and
`check --read-data` proved the repo on 05/08; how to reach it is in
[`arch-linux.md`](../../arch-linux.md).

Selection is by `by-id`, because sd/nvme names SHUFFLE between boots. NEVER use `/dev/nvmeXnY`.

To apply on a cutover, booting from the installer USB stick:

```sh
sudo nix run github:nix-community/disko -- --mode destroy,format,mount \
  --flake .#nixos-kingston
sudo nixos-install --flake .#nixos-kingston
```

## Why btrfs here, when the SanDisk is ext4

It is not for btrfs itself, it is for the SUBVOLUME LAYOUT, which is a prerequisite for
IMPERMANENCE (see the 30/07 entry in [`../history/2026/07-july.md`](../../history/2026/07-july.md):
an ephemeral root plus an explicit list of what persists, inspired by Misterio77's Foundry).
Impermanence requires `/nix` and `/persist` on volumes separate from the root FROM THE INSTALL
ONWARD; installing flat ext4 would mean reinstalling all over again to adopt it. The feature is
NOT on yet, and `@persist` is born empty on purpose. Turning it on later becomes a config change.

On a KC3000 (Phison E18, 800 TB TBW), CoW's write amplification is irrelevant at that volume, and
zstd REDUCES writes on compressible data. CoW fragmentation only bothers a database or a VM image,
and the `+C` for those cases is declared in
[`system/hardware/btrfs.nix`](../../../system/hardware/btrfs.nix).

## The mount options, and why these

**They are ONE binding in the file, and that is not cosmetic (23/08/2026).** The options used to be
repeated per subvolume, because disko has no inheritance, and the btrfs manual explains why 6 copies
were worse than duplication: *"Most mount options apply to the whole filesystem and only options in
the first mounted subvolume will take effect."* So the 5 copies outside `@` were DECORATION: editing
`@home`'s list alone would change nothing at runtime and read as if it had. One `btrfsOptions`
binding (rule 11) makes the truth visible and the change 1 line.

The consequence to remember: what the filesystem actually runs with comes from the FIRST mount,
which here is `/`. A per-subvolume policy is not something this layout can express, whatever the
config looks like.

**`compress=zstd:1` and not bare `zstd`** (which is level 3): on a Gen4 at ~7 GB/s the bottleneck
becomes the COMPRESSOR, not the disk. zstd:1 compresses several times faster for ~5-10% less
ratio, and DECOMPRESSION runs at the same speed on both levels, so reads lose nothing. On a 953 G
disk at 49%, the GiB saved by `:3` do not buy the cost on every `nixos-rebuild`.

Changing the level only affects NEW writes: what is already stored stays at zstd:3, which is
harmless. Rewriting would require `defragment -r -czstd`, which BREAKS reflinks and snapshots and
would multiply the used disk. Do not do it.

**`discard=async`** has been the kernel default since 6.2, but it is EXPLICIT on purpose: it is
what justifies `services.fstrim.enable = false` in
[`system/hardware/btrfs.nix`](../../../system/hardware/btrfs.nix). A policy that depends on an
implicit kernel default breaks silently on a bump, so if you take it out of here, turn fstrim back
on in the same commit.

## The swap trap

On btrfs a swapfile requires NOCOW and zero compression, otherwise the kernel refuses to activate
it. disko uses `btrfs filesystem mkswapfile`, which applies both attributes TO THE FILE, and that is
what actually makes it work.

REFINED on 23/08/2026, because this section used to say the missing `compress` on `@swap` was the
reason: it is not, since per the manual above a per-subvolume compress setting would not take effect
anyway. Leaving the options off `@swap` is honest bookkeeping, not the mechanism. What DOES depend on
`@swap` being its own subvolume is everything else: the swapfile stays out of the btrbk snapshots and
out of the future impermanence wipe.

The consequence: the `/swapfile` `swapDevices` left
[`system/hardware/hardware.nix`](../../../system/hardware/hardware.nix) (which is shared) and became
a host matter, declared here by disko.

## `@snapshots` is top-level, and it is not born on a rebuild

It holds the btrbk snapshots ([`system/services/btrbk.nix`](../../../system/services/btrbk.nix)). It
is a TOP-LEVEL subvolume and not a directory inside `@`, for two reasons: the impermanence
rollback would wipe `@` and take along exactly the history that exists to save your skin, and
outside `@home` restic never trips over it (otherwise it would back up every snapshot).

`nofail` is there because disko only runs on an install, so on an already installed system the
subvolume is created by hand, ONCE:

```sh
sudo mount -o subvolid=5 /dev/nvme0n1p2 /mnt \
  && sudo btrfs subvolume create /mnt/@snapshots && sudo umount /mnt
```

With `nofail`, forgetting that step costs you "btrbk does not run" (it demands the mount through
`RequiresMountsFor`) instead of "the boot falls into the emergency shell".

## What changes the day the disk dies (the 2032 question)

`device` carries the drive's SERIAL
(`/dev/disk/by-id/nvme-KINGSTON_SKC3000S1024G_50026B7686B3D2F6`), so a replacement drive is a ONE
LINE edit here and nothing else in the repo. That literal is the deliberate cost of `by-id`, which is
the only stable naming: `/dev/nvme0n1` shuffles between boots and would point the destroy at the
wrong disk, which is the one mistake in this file that cannot be undone.

Two other things belong to that day, and neither is in this file: the age key from the vault (see
[`../repo/secrets.md`](../repo/secrets.md), it is the only thing not in git) and `@snapshots`, which
disko creates on a real install but has to be created by hand on a machine that is already up.

## Formatting it from scratch, in a VM (23/08/2026)

`nix run .#disko-vm` builds a 24 GiB image with THIS layout, runs the real disko script against it
and boots the config on the result. It is the only check of this file: the gate proves the flake
evaluates, and nothing proved the partitioning still works, which is the one thing here that cannot
be fixed after the fact.

`hosts/nixos-kingston/vm-disko.nix` holds the three overrides that make it cheap: 24 GiB of image
instead of 953 (`size = "100%"` follows the image), 1 GiB of swap instead of 16 (`mkswapfile`
ALLOCATES it, so the real number would mean writing 16 GiB to check an integer), and the console on
the terminal so the drill also works over SSH. Leaving the VM is Ctrl-A then X.

**It REPORTS instead of waiting for a login**, because a console you cannot log into shows nothing:
a systemd unit prints the subvolumes, the btrfs mounts with their real options, the ESP, the active
swap and the failed units with their journal. What it printed on the first run:

```text
ID 256 gen 19 top level 5 path @        (plus @home @log @nix @persist @snapshots @swap)
/       /dev/vda2[/@]      rw,noatime,compress=zstd:1,discard=async,space_cache=v2,subvol=/@
/swap   /dev/vda2[/@swap]  rw,relatime,compress=zstd:1,discard=async,space_cache=v2,subvol=/@swap
/boot   /dev/vda1  vfat    rw,relatime,fmask=0077,dmask=0077,...
/swap/swapfile file 1024M
```

**That output PROVES the mount-option claim above, in both directions.** `@swap` came up with
`relatime` while every other subvolume has `noatime`, because atime is a VFS flag and IS per mount.
And `@swap` came up WITH `compress=zstd:1` even though this file never asks for it there, because
compression is a btrfs option and the FIRST mount decides for the whole filesystem. The swapfile
works anyway, which is the proof that what matters is `mkswapfile`'s attributes on the FILE.

Two more things it showed, neither of them in this file: systemd creates `srv`, `var/tmp`,
`var/lib/machines` and `var/lib/portables` as subvolumes INSIDE `@`, which matters for impermanence
(a wipe of `@` takes `/srv` along, and that is the 132 GiB library the open item already flags); and
`space_cache=v2` is on without being asked for, since it has been the default since 5.15.

WHAT IT DOES NOT PROVE: the bootloader. The VM boots the kernel directly (`useBootLoader` is off),
so GRUB, its Secure Boot signature and `os-prober` are outside this test. That half is still the
BIOS plus [`../../guides/secure-boot.md`](../../guides/secure-boot.md).
