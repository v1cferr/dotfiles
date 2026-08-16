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
it. That is why `@swap` is a subvolume OF ITS OWN and WITHOUT compress, and disko uses
`btrfs filesystem mkswapfile`, which already applies the right attributes.

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
