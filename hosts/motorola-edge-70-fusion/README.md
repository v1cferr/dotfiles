# Phone: a Motorola Edge 70 Fusion (stock Android)

My main phone: Android 17 (API 37, read by the first audit on 07/11/2026) on a Snapdragon 7s Gen 3, the bootloader LOCKED and no root, because
the banks, GOV.BR and Pix by tap (NFC) depend on a device that passes Play Integrity. Nix does
not run on it and never will, so this folder is DATA, the way [`../cudy-wr3000/`](../cudy-wr3000/)
is for the router.

[`default.nix`](default.nix) holds the phone's facts (manufacturer, model, LAN address) and its
desired POSTURE: verified boot, SELinux, the security patch age, a handful of settings, the system
packages that must stay enabled, and the permissions worth a review. `android-iac`
(`tools/android-iac/`) reads it as JSON and compares it with what the phone answers over ADB,
read-only.

## Usage

```sh
android-iac audit     # all of it in one go: connect (pair once), doctor, inspect, diff, plan, dry run, disconnect
android-iac doctor    # adb, the connection, the authorization, what can be read
android-iac inspect   # a sanitized report; --json for the full one, kept OUT of the repo
android-iac diff      # every declared check; exit 1 on drift, 3 on missing evidence
android-iac verify    # only what is not in sync, for scripts
android-iac plan      # what the `managed` block would change; saved under ~/.local/state, never run
android-iac apps      # the enabled third-party apps as the overlay JSON (android-iac-seal seals them)
android-iac apply --dry-run  # re-reads, refuses a stale plan, prints the exact commands, runs none
```

The session itself (pairing, authorizing, revoking afterwards) is
[`docs/guides/android-adb-session.md`](../../docs/guides/android-adb-session.md); the design and its
limits are [`docs/notes/hardware/android-iac.md`](../../docs/notes/hardware/android-iac.md) and
[ADR 0017](../../docs/decisions/0017-android-device-management.md).

## What is NOT here

**Anything that names me or the unit.** No serial, IMEI, Android ID, account, SSID or MAC:
the tool never prints them, and its tests run on synthetic output.

**My apps, in plain text.** The repo is public, and the list of apps a person banks with is not.
The third-party apps that must be present are versioned ENCRYPTED instead, as the sops key
`android_iac_local` in `secrets/secrets.yaml`, holding

```json
{ "mustBeInstalled": ["com.example.bank"] }
```

`android-iac-seal` pulls them from the phone, prints each app new and gone, asks, and seals; commit
`secrets/secrets.yaml`, then `rebuild`, which links `~/.config/android-iac/local.json` to
`/run/secrets/android_iac_local`. Reading that file needs no sudo, so the deployed list is always
one `jq . ~/.config/android-iac/local.json` away. Without it, `diff` says so instead of passing
those checks.

**A mirror.** Unlike the router, the phone's state is not copied into git: an inspect report
carries the app list, which is the private part.

## The address

`192.168.1.31`, a DHCP reservation on the router (`dhcp.edge_70_fusion`, added 07/11/2026). It is
tied to Android's RANDOMIZED per-network MAC, which is stable for this SSID until the network's
privacy setting changes or the phone's network settings are reset; then the reservation needs
the new MAC.
