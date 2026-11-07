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
| `state.py` | device selection, the reads, the inspect report |
| `compare.py` | declared against observed, one status per check |
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
device name, contacts, messages, and the list of apps I use. `inspect --json` carries the app list
and is personal: it goes to the terminal, never to a file in the tree. The tests use synthetic
output only.

## Future research, not a plan

A GSI, AOSP or a custom ROM (GrapheneOS does not support this phone) would make the device far
more declarative, and would also fail Play Integrity, which ends banking and NFC payments. It stays
here as research for a secondary device, never for this one.
