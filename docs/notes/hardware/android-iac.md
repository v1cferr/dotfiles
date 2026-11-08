# android-iac: the phone's posture, read over ADB

`tools/android-iac/`, installed by `modules/home/apps/android.nix`, and run by hand with the
phone connected. It reads [`hosts/motorola-edge-70-fusion/default.nix`](../../../hosts/motorola-edge-70-fusion/default.nix)
as JSON and compares it with what the phone answers. Why it exists and what was rejected:
[ADR 0017](../../decisions/0017-android-device-management.md). How to open and close a session:
[the guide](../../guides/android-adb-session.md).

## What it can and cannot do

Android is not NixOS. A NixOS host is BUILT from its declaration, so the declaration is the
system. A phone is only OBSERVED: the declaration is a list of expectations, and most of the
system sits behind permissions the ADB shell user does not have. Without root (and root is out,
see the ADR) this tool can read build properties, SELinux, settings the shell can read, the
package lists, each app's runtime permissions, and the NFC state. It cannot read app data, an
account, the lock screen's strength, most vendor settings, or anything under `/data`.

## The architecture

| File | Its one job |
| --- | --- |
| `adb.py` | the ONLY process call; an allowlist of read-only argv shapes checked before running |
| `parse.py` | adb's text output into data, tolerant of noise |
| `sanitize.py` | fail-safe redaction: allowlisted properties, identity-shaped keys dropped, a final scrubber |
| `spec.py` | the host JSON plus the local overlay, validated |
| `apps.py`, [`android-iac-seal`](../../../tools/android-iac/scripts/android-iac-seal.sh) | the phone's enabled third-party apps, sealed into sops as the overlay |
| `state.py` | device selection, the reads, the inspect report |
| `compare.py` | declared against observed, one status per check |
| `managed.py`, `plan.py`, `apply.py` | phase 2: the managed block, validated, the plan and its rehearsal (read-only) |
| `session.py` | `audit`'s connect, pair and disconnect, with their own allowlist of host-side commands |
| `doctor.py`, `cli.py` | the commands |

`audit` is the only command that changes anything, and only on THIS side: what the local adb
server is connected to. `connect`, `disconnect` and `pair` pass a second allowlist (an
`IPv4:port` argument and nothing else), and the pairing code travels on stdin, never in argv or
in an error. nixpkgs' `android-tools` is built without mDNS (`unknown host service 'mdns:check'`,
measured on 07/11/2026 with 35.0.2), so the port comes from `avahi-browse`, or from a prompt.

The allowlist is the safety property: `settings put`, `pm disable-user`, `pm uninstall`, `reboot`,
`su`, and an argument that could smuggle a second command into the remote shell are refused
before anything runs. The tests prove it with a fake adb that records every call.

## Reading the diff

| Status | Meaning | What to do |
| --- | --- | --- |
| `in-sync` | observed equals declared | nothing |
| `drift` | observed differs, with evidence | fix the phone, or change the declaration in a commit |
| `unknown` | no evidence: the read failed, or the key is unset and its default is unreadable | never read it as a pass |
| `unsupported` | the thing does not exist on this build (a package the vendor ships under another name) | fix the declaration |
| `manual` | only a person can settle it | look at the phone |

Exit codes, the same for `diff` and `verify`: `0` all in sync, `1` any drift, `3` no drift but
something is unknown, manual or unsupported, `2` the environment blocks the run (no adb, no phone,
not authorized, several phones, a broken spec).

Two `manual` results are expected on every audit: the debugging toggles are ON while it runs, and
the lock screen check can only prove the lock is not "None", since a swipe answers the same.

## Security policy

Never root, never unlock the bootloader, never touch system partitions, Verified Boot or SELinux,
never install Magisk or anything that hides from Play Integrity, never wipe, reset or debloat. The
tool cannot do any of this by construction, and phase 2's writes, when they come, are limited to
the allowlist the ADR describes.

## What never enters the repo

Serials, IMEI, MEID, the Android ID, MAC and Bluetooth addresses, SSIDs, account names, the
device name, contacts, messages, and the list of apps I use in plain text (it is sealed in sops,
see the host README). `inspect --json` carries the app list
and is personal: it goes to the terminal, never to a file in the tree. The tests use synthetic
output only.

## Phase 2: writing, designed on 07/11/2026

The ADR fixes the contract; this is the design that meets it. What ADB can write without root is
real (the shell user holds `WRITE_SECURE_SETTINGS`, and `pm` can disable packages and revoke
permissions), so phase 2 uses exactly that and nothing past it.

**Three policies per item.** `audit` (what exists: read and compare), `managed` (the tool may fix
it), `manual` (only a person can). Managed items live in their own block of the host file:

```nix
managed = {
  settings.global.stay_on_while_plugged_in = "0";
  packagesDisabled = [ "com.vendor.bloat" ]; # pm disable-user --user 0
  permissionsRevoked."org.example.app" = [ "android.permission.RECORD_AUDIO" ]; # pm revoke
};
```

The spec refuses a managed key that is also audited or manual, a value that is not a number or a
package/component name, and disabling anything in `mustBeEnabled` or in a floor written in the
code (Play Services, the Play Store, NFC, the phone, SystemUI, Settings, WebView, the permission
controller).

**A second allowlist, for writes only**: `settings put` and (for rollback) `settings delete`,
`pm disable-user --user 0` and `pm enable`, `pm revoke` and `pm grant`. Refused by construction:
`pm uninstall`, `pm clear`, `reboot`, any reset or wipe, `su`, `fastboot`. Only values the
sanitizer already lets through can be written, so the log is sanitized AND holds the exact
previous value a rollback needs.

**Four steps, never skipped:**

1. `plan` reads the phone fresh and lists only the operations where observed differs from
   declared (idempotent: an in-sync phone plans nothing). Each carries its before and after
   values, whether it is reversible and whether it is sensitive. A managed item it cannot read
   blocks the plan instead of being guessed. The plan is saved under
   `$XDG_STATE_HOME/android-iac/plans/` (mode 0600, never in the repo) with the spec's digest and
   the build fingerprint.
2. `apply --dry-run <plan>` reads again, refuses a plan the phone has moved away from, prints the
   exact commands, and marks the plan rehearsed.
3. `apply <plan>` requires that rehearsal, of that plan, under 10 minutes old; asks a typed
   confirmation for sensitive operations (`secure.*`, connectivity, permissions); runs one
   operation at a time, re-reads each to verify, and stops at the first failure. Every step goes
   to a JSONL journal under `$XDG_STATE_HOME/android-iac/journal/`.
4. `rollback <journal>` undoes in reverse order, but only the operations whose current value is
   still what `apply` left; one changed by hand since is skipped and reported as drift. A key that
   did not exist before is removed with `settings delete`.

What stays irreversible is simply not offered: uninstalling, clearing data, resetting. An OTA can
still reset a value or rename a key, which the next `plan` shows.

**Status**: 2a delivered on 07/11/2026: `plan` (`plan.py`, the block in `managed.py`, the write
shapes in `adb.py`) exits 0 with nothing to change, 1 with a plan saved, 3 when something is
blocked, in which case nothing is saved. `diff` shows managed items as `managed <target>`.
2b delivered the same day: `apply --dry-run [plan]` (`apply.py`, the latest plan by default)
refuses a plan whose declaration digest, build fingerprint or operations no longer match a fresh
read, rebuilds the commands from that read (never from the file), and writes the rehearsal mark
(the plan's sha256 and the time, 0600) under `rehearsals/`. Exit 0 rehearsed, 1 refused, 2 no
usable plan. `apply` without `--dry-run` is refused until 2c. `audit` runs both after the diff
when the host declares a `managed` block, the rehearsal on a second fresh read.

**Delivery, one usable step per commit**: 2a `plan` (read-only); 2b `apply --dry-run`; 2c
`apply` and `rollback` for settings, starting with harmless keys; 2d packages; 2e permissions.
Each with tests on a fake phone whose state changes when it is written to.

## Future research, not a plan

A GSI, AOSP or a custom ROM (GrapheneOS does not support this phone) would make the device far
more declarative, and would also fail Play Integrity, which ends banking and NFC payments. It stays
here as research for a secondary device, never for this one.
