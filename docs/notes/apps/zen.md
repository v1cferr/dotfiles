# Zen: the launch guard, and the NSS check that had to be written backwards

`home/apps/zen.nix`. The browser, plus a guard that closes it when the screen stays locked and asks
for Zen's own primary password on the next launch.

## What this is NOT, and why that is the point

People who sit at this machine know my login password, and this account is in `wheel` with
`security.sudo.wheelNeedsPassword = true`. **Whoever knows that password is root here**, so any lock
that lives inside the browser or leans on file permissions is a speed bump and nothing else: the
profile can be copied out of `~/.zen` and opened somewhere quieter.

The only thing that survives an adversary with root is a passphrase that never touches the disk,
which means an encrypted profile. That was designed and REJECTED, see below. What I asked for and
what this module delivers is the speed bump: a UI barrier against someone opening my browser and
finding every session already logged in.

## Why Zen's own primary password and not a secret of my own

Rule 12 says the repo never holds a credential, and a new password would mean a Bitwarden item, a
`sync-secrets` run and a second password to remember for the same browser. Zen already has one that
does half the job (it encrypts `logins.json` through `key4.db`), and NSS already knows how to verify
it from outside the browser:

```text
certutil -K -d sql:<profile> -f /dev/stdin
```

The password arrives on stdin, so it is never written anywhere. One password, no new secret, and
turning it on protects the saved logins at the same time.

## The NSS trap: no password means EVERY password

With no primary password set, NSS authenticates with the empty one and **ignores whatever it is
handed**. A profile in that state answers "fine" to any string, so a naive check would produce a
prompt that looks like security and is not. The only way to tell "set" from "not set" is to offer a
deliberately wrong password and look for `SEC_ERROR_BAD_PASSWORD`, which is what the probe in `arm`
does.

That is also why `nss_accepts` is written POSITIVELY. Reading it as "not a bad password" would turn
a broken db, a missing `certutil` or any unexpected output into a free pass. It returns 0 only when
NSS actually answered, and everything else is a refusal.

**And the pipeline has to be captured, not piped into `grep`**: under `set -o pipefail`,
`printf | certutil | grep -q` returns certutil's 255 even when grep matched, because certutil exits
non-zero on the happy path too ("no keys found"). The output goes into a variable first.

## Two preconditions, and why it disarms out loud instead of proceeding

`arm` checks both and, when either fails, writes a priority-4 line to the journal, leaves Zen alone
and does not arm:

1. **A primary password exists**, for the reason above. A guard that cannot verify is not a guard.
2. **Zen reopens the previous session**. `browser.startup.page` defaults to `1` in Zen 1.22b
   (measured inside `browser/omni.ja`, `defaults/preferences/firefox.js`), and `prefs.js` only
   records non-default values, so the pref being absent means the tabs are gone on close. Closing a
   browser that does not come back is not a security feature, it is data loss.

Both are UI settings I flip inside Zen. Until I do, the journal says `DISARMED` on every lock, which
is rule 16's shape of failure: loud, never silent.

## Killing precisely, because `pgrep -f` is wider than it looks

SIGTERM is Firefox's clean quit: it writes `sessionstore` and exits, the same path a logout takes.
SIGKILL only runs after 10 seconds of waiting.

Finding the process is the delicate half. The parent carries `--class=zen-beta` in its cmdline and
the content processes do not, so `pgrep -f` looks like enough, and it is not: while writing this it
also matched **the shell running the `pgrep` itself**, because the pattern was sitting in that
command line. Every candidate is confirmed through `/proc/<pid>/exe` against `*/lib/zen-bin-*/zen`
before anything is signalled.

## The wiring, and where it deliberately does NOT live

The countdown is a TIMER with `WantedBy=hyprlock.service` and `BindsTo=hyprlock.service`. Locking the
screen pulls it in, `OnActiveSec` counts the grace, and unlocking in time stops the timer and cancels
the pending close. Coffee does not cost me the browser; walking away does.

**`BindsTo` and not `PartOf`, and this one was measured, not read.** `PartOf` is what
`lockscreen-idle-lock` uses and it was the obvious first choice here, but it only propagates an
EXPLICIT stop. hyprlock is `Type=simple` and ENDS BY ITSELF when the screen is unlocked, and a unit
that exits on its own enqueues no stop job, so nothing reaches the timer. Two throwaway units proved
it: parent exits on its own, `is-active` on the `PartOf` timer still says `active`. The countdown
would have survived the unlock and closed Zen three minutes into me using it, which is the worst
possible shape for this feature. `BindsTo` plus `After` stops on the bound unit going inactive for
ANY reason, and the same test says `inactive`.

**The coupling is declared in `zen.nix` and not in `lockscreen.nix`** on purpose. The lock is a
security function and must not become hostage to a browser module, and `WantedBy` produces a weak
`Wants=`, so a guard that fails to start can never hold the screen unlocked.

The armed flag lives in `$XDG_STATE_HOME/zen-guard/armed` and not in `/run`: **a reboot must not be
the way around the prompt**. Booting locks the screen (`autostart.lua`), so a fresh boot arms it
after the same grace.

The escape hatch, when the check itself breaks, is `rm ~/.local/state/zen-guard/armed`.

## What was designed and rejected

**A gocryptfs vault over `~/.zen`** (4.5 GB, ciphertext beside it, unmounted on lock). This is the
only option on the list that holds against root, and it is the one I did not want: it means
re-encrypting the whole profile, FUSE in the path of every sqlite write the browser makes, and a new
user mount inside `/home`, which is the exact trap
[`restic.md`](../boot-and-storage/restic.md) records three times. If it ever comes back, the prompt
does not change, only what it unlocks.

**`fscrypt`**, the kernel's own per-directory encryption, would have been the elegant version of the
same idea: no FUSE, and `fscrypt lock` is instant. It supports ext4, F2FS and UBIFS, and this home is
btrfs.

**Browser extensions** (Browser Lock, Locksy and friends) live inside the profile they claim to
protect and switch off in `about:addons`.

**Hiding the windows in a Hyprland special workspace** instead of closing Zen: no session loss and no
preconditions at all, but the browser stays in RAM one `hyprctl dispatch` away. It is the fallback if
closing the browser ever becomes annoying in practice.
