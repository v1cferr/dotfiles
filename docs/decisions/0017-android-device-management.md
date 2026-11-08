# 0017. The phone is audited over ADB, read-only, against a declared posture

The main phone becomes a managed device the way the router is: the repo declares what it should
be, and a tool on the desk observes it and reports drift. Phase 1 never writes to it.

- **Status**: accepted
- **Date**: 07/11/2026

## Context

A new main phone, a Motorola Edge 70 Fusion on Android 16, arrived for a clean install. It
carries the banks, GOV.BR, NFC payments and authentication, so its integrity matters more than
its convenience. Until now the repo only had `adb` and `scrcpy` for hand work on the previous
phone ([android](../notes/hardware/android.md)): nothing said what the phone SHOULD look like,
and nothing would notice when it stopped.

Android is not NixOS. Without root, most of the system is out of reach, an OTA can change any
default, an app's data cannot be declared, and many settings cannot be read at all. So the
question was how much management is possible without weakening the device.

What was compared and REJECTED:

- **Root (Magisk) or an unlocked bootloader**, which would make most of the system reachable:
  they fail Play Integrity's device and strong verdicts, which the banks and GOV.BR check, and
  bypassing that is exactly what this phone must never do.
- **A GSI, AOSP or a custom ROM**, the closest Android gets to declarative: the same integrity
  failure, and NFC payments with it. Kept as research only.
- **Android Enterprise (a device policy controller)**: the real management API, but it means
  provisioning the phone as work-managed or with a work profile, a heavy dependency for a personal
  phone. Worth a look for phase 2's writes.
- **A mirror in git, like the router's**: the phone's state includes its app list, which is
  personal, and the repo is public.
- **YAML files per concern** (packages, permissions, settings, security): a parser dependency
  for data that Nix already expresses, and serializes with `builtins.toJSON` (rule 24, step 1).

## Decision

- `hosts/motorola-edge-70-fusion/default.nix` is plain data: facts and a desired POSTURE. It is
  not a NixOS host and is not in `nixosConfigurations`. Private items (third-party apps) are
  versioned encrypted in sops (amended 07/11/2026: an untracked local file at first, which left
  state outside the repo that nothing could audit).
- `tools/android-iac/` is a Python program (stdlib only, typed and tested at build, registered
  under [rule 24](../notes/repo/languages.md)) with four read-only commands: `doctor`, `inspect`,
  `diff`, `verify`. Every adb call passes an allowlist of read-only command shapes BEFORE it runs,
  so "never writes" is structural, not a promise.
- Every result is one of `in-sync`, `drift`, `unsupported`, `unknown` or `manual`, and a check
  without evidence is `unknown`, never `in-sync`.
- ADB is a temporary session the person opens and closes on the phone. The tool never enables
  anything there; `audit` only pairs and connects THIS computer's adb, through an allowlist of its
  own, and disconnects at the end. Turning debugging off stays a human step.

## Phase 2, designed but not built

`plan`, `apply --dry-run`, `apply` and `rollback` come only with:

- an explicit allowlist of writable keys (`settings put` on named keys, `pm disable-user` on named
  packages), each marked reversible or not, and nothing outside it;
- idempotence: a change is planned only when observed differs from declared;
- validation first: the plan is computed from a fresh read, and `apply` refuses a stale plan;
- dry-run first: `apply` runs only after a dry-run of the same plan, and sensitive keys
  (security, connectivity, anything under `manualSettings`) ask for confirmation;
- a sanitized log of every operation, with the PREVIOUS value, kept out of the repo;
- rollback only where a previous value was recorded. Uninstalling an app, losing its data,
  clearing a credential or anything an OTA resets is irreversible, refused by the planner and
  listed as such.

Rollback is not universal on Android, and the tool will not pretend it is.

## Consequences

- The phone's security posture is visible and checkable on demand: verified boot, a locked
  bootloader, SELinux, the patch age, accessibility services, the packages NFC payments need.
- Much stays manual, on purpose: the debugging toggles themselves, the lock screen's strength
  (a swipe reads like a PIN to an unprivileged read), every setting the shell user cannot read.
- An OTA can rename a key or a package. That shows up as `unknown` or `unsupported`, not as a
  pass, and the declaration is updated in a commit.
- The fixed LAN address is a router reservation for a randomized MAC, which a privacy change on
  the phone breaks.
