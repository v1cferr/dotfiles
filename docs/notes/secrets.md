# secrets

Modules: [`system/core/secrets.nix`](../../system/core/secrets.nix),
[`scripts/sync-secrets.sh`](../../scripts/sync-secrets.sh), [`.sops.yaml`](../../.sops.yaml)

Bitwarden is the source of truth, sops is the vault, and the repo never holds a credential
(rule 12).

## How the two layers fit

The PUBLIC index [`secrets/bitwarden-secrets.json`](../../secrets/bitwarden-secrets.json) maps
name-in-sops to item-in-Bitwarden. It is not a secret, so it goes into git. From it:

1. Nix GENERATES the `sops.secrets.<name>` entries on its own, so no declaring one by hand again.
2. `sync-secrets` pulls the values from Bitwarden and writes them ENCRYPTED into `secrets.yaml`
   (through `sops set`), which is what keeps the rebuild PURE, with no `--impure`.

Adding a secret: register it in Bitwarden, add 1 line to the JSON, run `sync-secrets`, then
`nixos-rebuild switch`. Secrets that do NOT come from Bitwarden (the user's password hash, for
instance) stay declared by hand.

**The order matters.** Entering the index makes sops DECLARE the secret, and a declared secret
whose key is not in `secrets.yaml` yet passes the BUILD and breaks at ACTIVATION with
`secret does not exist`, taking the switch down. That is why the conditional declarations exist:
the module stays inert until `sync-secrets` has run.

## Two recipients, on purpose

The public keys in `.sops.yaml` are who CAN decrypt; each private half lives outside git.

| Recipient | Where the private key is | Why it exists |
| --- | --- | --- |
| host | `/var/lib/sops-nix/key.txt` on the machine | what sops-nix uses at boot to populate `/run/secrets`, and what you carry across a cutover |
| backup | offline, generated 04/08/2026 | a SINGLE recipient means IRREVERSIBLE loss of every secret the day that key disappears |

sops has no recovery. Before the offline key, the only backup of the host key was Bitwarden, which
made Bitwarden the SPOF of everything. With two, losing one is an annoyance; losing both is the
disaster.

The `host` anchor said `nixos_seagate` until 04/08/2026: the key was BORN on that host and was
carried in the cutover to the Kingston (01/08/2026), so it is the same key under an old name.

**`creation_rules` only applies to a NEW file.** Adding a recipient does NOT re-encrypt what
already exists, so without running `sops updatekeys secrets/secrets.yaml` the new key decrypts
nothing and the backup is imaginary.

The regex only catches `secrets/*.yaml`. `bitwarden-secrets.json` is plain text ON PURPOSE, but a
`.json` that some day holds a secret would NOT be encrypted by that rule.

## Who can read what, and why some secrets are user-owned

Most secrets are root-only. These are not, and each has a reason:

| Secret | Owner | Why |
| --- | --- | --- |
| `rclone_gdrive_conf` | v1cferr 0400 | the `~/Drive` mount is a `--user` service and has to read it without sudo |
| `restic_password`, `restic_password_arch_kingston` | v1cferr 0400 | `restic mount` is only browsable by WHOEVER MOUNTED IT |
| `jellyfin_api_key`, `deepl_api_key`, `ntfy_topic` | v1cferr 0400 | consumed by user tooling and `--user` timers |

The restic one is the least obvious and the most defensible: a FUSE mount is private by default,
which this config already proved inside out, since restic as ROOT could not even `lstat` the
USER's FUSE mount at `~/FAI-workstation`. Mounting with sudo gives a folder Dolphin does not open,
so mounting as the user requires reading the password without sudo. It is not privilege
escalation: it is the backup password for THAT SAME USER'S data, and whoever already is v1cferr
has the original files.

`rclone_gdrive_conf` stays OUT of Bitwarden on purpose: it is MULTILINE and `sync-secrets` does a
`sops set` with single-line JSON, which would break it. And unlike the restic password, the OAuth
token is regenerable, so it does not need the vault.

## Editing by hand

```sh
nix shell nixpkgs#sops -c sops secrets/secrets.yaml           # edit
nix shell nixpkgs#sops -c sops updatekeys secrets/secrets.yaml # after adding a recipient
```

A `rebuild` is MANDATORY after editing, otherwise `/run/secrets` does not update.

## Two recipients, and the `updatekeys` trap

`.sops.yaml` lists the PUBLIC keys of who CAN decrypt; each one's private half lives OUTSIDE git.
There are TWO on purpose:

- **host**: `/var/lib/sops-nix/key.txt` on the machine. It is what sops-nix uses at boot to populate
  `/run/secrets`, and what you carry across a cutover. The anchor said `nixos_seagate` until
  04/08/2026, because the key was BORN on that host and was carried in the cutover to the Kingston
  (01/08/2026): the same key, a new host, an old name.
- **backup**: an OFFLINE key (generated 04/08/2026) that does NOT sit on a machine nor in the cloud
  in the clear. It exists because a SINGLE recipient means IRREVERSIBLE loss of every secret in the
  repo the day that key disappears, since sops has no recovery and its only backup was Bitwarden,
  the SPOF of everything. With two, losing one is an annoyance; losing both is the disaster.

```sh
nix shell nixpkgs#sops -c sops secrets/secrets.yaml             # edit
nix shell nixpkgs#sops -c sops updatekeys secrets/secrets.yaml  # re-encrypt for new keys
```

**WARNING**: `creation_rules` only applies to a NEW file. Adding a recipient does NOT re-encrypt
what already exists, so without running `updatekeys` the new key decrypts nothing and the backup is
imaginary.

And the regex only catches `secrets/*.yaml`. `bitwarden-secrets.json` is plain text ON PURPOSE (a
name-in-sops to item-in-Bitwarden map, with no credential), but a `.json` that some day holds a
secret would NOT be encrypted by this rule.
