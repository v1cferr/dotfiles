# Disaster recovery: the protocol that proves this repo rebuilds the machine

This repo claims to be the SSOT of my infrastructure. A claim with no rehearsal is a belief, and the
day it stops being true is the day I need it. So there are three drills, cheapest first, and each one
says exactly what it does NOT prove.

## The one thing that is not in git

The age key. Everything else, including every secret, is either in the tree or reproducible from it;
`secrets/secrets.yaml` is encrypted FOR that key. Two recipients exist on purpose
([`../notes/repo/secrets.md`](../notes/repo/secrets.md)): the host key at
`/var/lib/sops-nix/key.txt` and an offline backup. Lose both and every secret is gone, permanently.

And the cascade is bigger than "no passwords", which the disko VM measured on 23/08/2026: with no
key, `sops-install-secrets` fails in the initrd, so the user's `hashedPasswordFile` never appears,
and on a fresh install that used to take home-manager down with it (see
[`../notes/boot-and-storage/disko.md`](../notes/boot-and-storage/disko.md)). A restore without the
key does not degrade gracefully.

## Why the key does NOT get copied into this repo

The tempting shortcut is to pull it from Bitwarden once into a `.env` next to the flake and be done.
Refused, and not on principle: three concrete reasons and one precedent.

1. **This repo is PUBLIC.** A key in the working tree is one `git add -f`, one `git stash`, or one
   careless glob away from being published forever. `.gitignore` protects against a typo, not
   against a mistake, and there is no rotating your way out of a published master key: it decrypts
   every value ever committed to `secrets.yaml`, including in the history.
2. **It would sit in reach of everything running as this user**: an editor extension, an `npm
   postinstall`, an AI agent with file access, a misconfigured sync client. The key is root-owned
   `0600` at `/var/lib/sops-nix/key.txt` for exactly that reason, and copying it into `$HOME` throws
   that away.
3. **The repo folder is inside `$HOME`**, so it is in reach of the backups and of every future
   clone. A secret whose whole design is "outside git" would come back in through restic.

THE PRECEDENT, and it is this repo's own: `scripts/sync-secrets.sh` already needs the key and reads
it as `SOPS_AGE_KEY="$(sudo cat /var/lib/sops-nix/key.txt)"`, with the comment "read ONLY into the
process' memory, it does not go to disk". The drills below follow the same rule: the key passes
through the ENVIRONMENT or through a tmpfs that dies with the boot, never through the repo.

## D1, weekly and automatic: does the config still boot

Nothing to do. `home/services/vm-boot-drill.nix` runs `nix build .#vm-boot` every Sunday, silent on
success and one ntfy push on failure. It boots the whole config in QEMU and asserts that it was
APPLIED: `multi-user.target`, sshd, the user with their shell, the home-manager generation with
`Result=success`, and no failed unit ([`../notes/repo/vm-boot.md`](../notes/repo/vm-boot.md)).

It does NOT touch the disk layout, the secrets, the GPU or the bootloader.

## D2, quarterly, about 10 minutes: does the LAYOUT still format

```sh
nix run .#disko-vm     # Ctrl-A then X to leave the VM
```

It builds a 24 GiB image, runs the REAL disko script against it, boots the config on the result and
prints a report. Read four things in it:

- **the 7 subvolumes**: `@ @home @log @nix @persist @snapshots @swap`
- **the mount options**, and remember that only the first mount decides for the filesystem: `/` must
  show `noatime,compress=zstd:1,discard=async`
- **the swap line**: `/swap/swapfile file` present means `mkswapfile` did its job
- **zero failed units**, and nothing hidden under `@/home` (that section is a regression guard for
  the first-boot bug this VM found)

It does NOT prove the bootloader: the VM boots the kernel directly, so GRUB, its Secure Boot
signature and `os-prober` are outside it. That half lives in
[`secure-boot.md`](secure-boot.md) and in the BIOS.

## D3, yearly or before touching hardware: the secrets half

The only drill that needs the key, and the one that proves the claim "the public repo plus the vault
is enough".

```sh
# 1. a scratch directory on TMPFS: it dies with this boot, and it is not in the repo
d=$(mktemp -d -p "$XDG_RUNTIME_DIR") && chmod 700 "$d"

# 2. a CLEAN clone, over https and with no local state, exactly what a stranger machine gets
git clone https://github.com/v1cferr/dotfiles "$d/dotfiles"

# 3. the key from the vault, into the ENVIRONMENT and not into a file. The item's name and shape
#    (a note, a custom field, an attachment) is whatever the vault says, so find it first:
export BW_SESSION=$(bw unlock --raw)
bw list items --search age | jq -r '.[] | .name'
export SOPS_AGE_KEY="$(bw get notes '<the item the line above named>')"

# 4. THE ACTUAL TEST: does that key decrypt the repo's secrets?
cd "$d/dotfiles" && nix shell nixpkgs#sops -c sops -d secrets/secrets.yaml | head -3

# 5. clean up. The tmpfs would go on reboot anyway; do not wait for it.
unset SOPS_AGE_KEY BW_SESSION && rm -rf "$d"
```

If step 4 prints plaintext, the disaster-recovery claim holds: a stranger machine plus the vault
reproduces every secret. If it fails, fix THAT before anything else, because no other drill can
substitute for it.

Do the same with the OFFLINE backup key at least once a year, since a backup nobody has ever read is
a backup nobody knows is empty.

## The real thing: the disk died and a new one is in

In order, and step 4 is the one that is easy to forget and expensive to skip.

1. Boot the installer USB stick, `git clone https://github.com/v1cferr/dotfiles`.
2. **ONE line changes**: `device` in `hosts/nixos-kingston/disko.nix` carries the drive's SERIAL, so
   the new disk needs its own `by-id` path. Nothing else in the repo knows the disk.
3. Format and mount:

   ```sh
   sudo nix run github:nix-community/disko -- --mode destroy,format,mount --flake .#nixos-kingston
   ```

4. **Put the key in place BEFORE the first boot**, or the cascade at the top of this page happens on
   a machine you are trying to rescue:

   ```sh
   sudo install -D -m 0600 /dev/stdin /mnt/var/lib/sops-nix/key.txt   # paste the key, then Ctrl-D
   ```

5. `sudo nixos-install --flake .#nixos-kingston`, then reboot.
6. After the first boot: create `@snapshots` by hand (the command is in the
   [disko note](../notes/boot-and-storage/disko.md)), then restore from restic what rule 6 says was
   never declared (saves, Wine prefixes, app sessions).
7. Secure Boot needs its own pass: the sbctl keys live in `/var/lib/sbctl`, are NOT in git, and
   enrolling them is manual ([`secure-boot.md`](secure-boot.md)).

## What no drill here covers

The GPU and the compositor (a VM has neither), the router (its own mirror and its own guide), the
Windows side of the dualboot, and every step that happens in the BIOS. Those are not gaps to close
by writing more Nix: they are the honest edge of what a declarative config can promise.
