# 0006. The disks are not encrypted

The NixOS disk has no LUKS: a risk accepted on purpose, with what it exposes written down.

- **Status**: accepted, review by 2027-09-30
- **Date**: 30/09/2026

## Context

Full-disk encryption (LUKS, unlocked by the TPM2 through `systemd-cryptenroll`) is the standard
answer to a stolen disk, and the NixOS community treats it as a default for laptops. This is a
desktop that stays at home, formatted by disko with btrfs and no LUKS layer, and adding one means
reformatting.

## Decision

No disk encryption. The threat it answers, someone walking away with the machine or the NVMe, is
accepted for a desktop that does not leave the house.

## Consequences

- **What a stolen disk hands over**: all of `~`; the sops age key at `/var/lib/sops-nix/key.txt`,
  which decrypts every secret in `secrets/secrets.yaml` (so a theft means rotating all of them,
  starting from Bitwarden); the SSH host keys; and the Secure Boot signing keys under
  `/var/lib/sbctl`.
- **The `docker` group is root-equivalent** for `v1cferr`, so a compromised session is root either
  way; rootless Docker was not adopted, since three stacks use host networking.
- The review date is when this is asked again, and the natural moment to change it is the next
  reinstall, with a backup in place first, which is decision 0008.
