# 0016. Bitwarden is the single source of secrets, home included

Every secret has one home, the Bitwarden vault. The machine consumes the ones it needs through the
existing sops-nix pipeline, and nothing secret lives loose in `~`.

- **Status**: accepted
- **Date**: 28/10/2026

## Context

The system's secrets already flowed from one place: Bitwarden, then `sync-secrets` into
`secrets/secrets.yaml` (sops, two age recipients), then `/run/secrets`
([secrets](../notes/repo/secrets.md), rule 12). The home never followed. The first run of
`persist-diff` ([impermanence](../notes/boot-and-storage/impermanence.md)) listed, on 28/10/2026,
an age key backup, a WireGuard client config, a router backup, API keys and recovery codes as
plain files, two of them world-readable (`644`).

The question was whether to keep that pipeline or centralize somewhere else, the way OpenBao does
it at work. What lost, and why:

- **OpenBao (or Vault) with vault-agent**: dynamic secrets and audit are built for a team. For one
  machine it adds a server to keep up, its own storage to back up, and an unseal step after every
  power cut, on a machine that must come back on its own (autologin, Sunshine). Secrets fetched at
  runtime also stop working with the network down.
- **Vaultwarden, self-hosted**: the same experience as Bitwarden, plus one more critical service
  to run and back up.
- **agenix**: simpler than sops-nix, but the repo already runs sops-nix with an offline recovery
  recipient. Swapping gains nothing.
- **clan vars**: generators and per-machine secrets, at the price of adopting the clan framework.
- **opnix (1Password) or `bws` (Bitwarden Secrets Manager)**: fetch from the vault at activation.
  opnix looked unmaintained, and `bws` is a separate paid product beside the vault already in use.

The kept design is the pattern the community packages as Sopsidy: a password manager as the source
of truth, sops-nix as the encrypted, offline-capable copy the build reads.

## Decision

Bitwarden is the only source. A secret falls into one of three kinds, and the kind decides where it
goes:

| Kind | What it is | Where it lives |
| --- | --- | --- |
| **config** | a value the machine needs to work (an API token, a VPN password) | Bitwarden, then sops, then `/run/secrets` |
| **session** | a login an app makes and refreshes itself (gh, vercel, azure, docker, browsers) | the app's own state, kept by `my.persist`; logging in again is its source |
| **cold** | recovery or archive material nothing reads (key backups, recovery codes, old configs) | only in Bitwarden, as a secure note or attachment; no local copy |

## Consequences

- Bitwarden becomes the place to lose everything, and that is the accepted trade: the offline age
  recipient still decrypts `secrets.yaml` without it, and the vault has its own export routine.
- Cold secrets that leave the home stay in the btrbk snapshots until those expire; nobody deletes
  snapshots by hand to speed that up.
- A session login is lost if its folder is missing from `my.persist`. That costs a login, never a
  secret, which is why session tokens are not copied into sops.
- `~/.ssh/id_ed25519` has no passphrase on a disk without encryption
  ([0006](0006-no-disk-encryption.md)). Fixing that needs the two rclone mounts that use the key
  unattended to move to the keyring's agent first, so it is a separate step.
