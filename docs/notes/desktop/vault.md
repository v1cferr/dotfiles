# The app vault: sensitive apps ask for the password again

The session lock already covers leaving the desk: hypridle locks after 5 minutes
([`lockscreen.md`](lockscreen.md)). The vault is a smaller layer inside an unlocked session. A
sensitive app that sat unfocused for 5 minutes disappears, and getting it back asks for the login
password, the way Bitwarden's vault timeout or Android's App Lock behave.

## What it is, and what it is not

A speed bump against a curious passer-by, the same model as the Zen guard
([`../apps/zen.md`](../apps/zen.md)). It is NOT a security boundary: anyone at an unlocked
session with a terminal can run `hyprctl eval 'vault.release("discord")'` or open
`special:vault`, and the apps' data on disk is untouched. For real protection the screen lock is
the boundary, and an app's own lock is the second one where it has one (see the end).

The apps are hidden, never closed: they keep running, notifying and playing audio.

## How it works

Two halves, joined by IPC:

| Part | File | Job |
| --- | --- | --- |
| The clock and the hiding | [`hypr/lua/vault.lua`](../../../modules/home/desktop/hypr/lua/vault.lua) | which classes count, the grace, moving windows to `special:vault` and back |
| The password card | [`quickshell/Vault.qml`](../../../modules/home/desktop/quickshell/Vault.qml), [`vault/VaultPrompt.qml`](../../../modules/home/desktop/quickshell/vault/VaultPrompt.qml) | which apps it asks for, the PAM conversation, calling `vault.release(app)` back |

- **The clock.** `window.active` records when each vault app lost focus. A 30 s `hl.timer` hides
  every app whose last focus is older than `GRACE` (300 s), even one still visible on the other
  monitor. A background app that never had focus starts its clock when its window opens.
- **Playing media keeps an app on screen.** A stream watched on the other monitor is in use with
  no focus at all. `Vault.qml` watches the MPRIS players and pushes their desktop entries
  (`"zen"`) to `vault.set_playing()` on every change; the grace skips those apps, and an app's
  clock starts over when it stops playing, so a paused stream still gets the full 5 minutes. The
  session lock hides it anyway: the screen is locked, and a hidden player keeps playing.
- **Hiding** moves every window of the app to `special:vault` with `follow = false`.
- **Reaching for it.** Focusing a hidden window (alt-tab, a stray dispatch) or a hidden app opening
  a new window puts it back in the vault and runs `qs ipc call vault ask <app>`. SUPER+CTRL+V asks
  for everything hidden at once, and SUPER+CTRL+L hides everything now.
- **The session lock** hides every vault app first: `lockscreen.service` runs
  `hyprctl eval 'vault.lock_all()'` as an `ExecStartPre` prefixed with `-`, so a failure there never
  keeps the screen from locking.
- **The card** reuses the lock's [`lock/Auth.qml`](../../../modules/home/desktop/quickshell/lock/Auth.qml)
  and so the `quickshell-lock` PAM service: the same password, with no second service to keep. It
  sits on the focused monitor only, over a dim scrim, with exclusive keyboard focus. Esc or a click
  outside cancels and the apps stay hidden. Three misses in a row wait 30 s.
- **After `hyprctl reload`** the Lua tables start empty, so anything already in `special:vault`
  counts as hidden again, every other open vault app restarts its clock, and the Lua asks
  `qs ipc call vault sync` for who is playing.
- **To see the state**: `hyprctl repl 'return vault.status()'` prints each open app as `hidden`,
  `playing`, `focused` or `idle Ns`.

### The apps

The classes are Lua patterns over the lowercased window class, because X11 and Wayland report
different ids for the same app:

| App | Classes |
| --- | --- |
| Discord | `discord`, `vesktop` |
| Telegram | `TelegramDesktop`, `org.telegram.desktop` |
| ChatGPT | `chatgpt` |
| Obsidian | `obsidian`, `md.Obsidian` |
| Zen | `zen*` |
| LibreWolf | `librewolf` |

Adding an app is one line in `APPS` (vault.lua) plus its name and icon in `Vault.qml`. The `.lua`
is hot-reloaded, so `hyprctl reload` applies it with no rebuild.

## Pitfalls found while building it

- **Focusing a window in a special workspace OPENS that special** on its monitor, so the hidden app
  showed up on screen the moment anything focused it. `close_view()` closes it again. Since
  `toggle_special` only acts on the FOCUSED monitor, it first focuses each monitor that shows the
  vault (measured 03/11/2026: a bare toggle opened the vault on the other monitor instead).
- **One reach fired two `window.active` events**, so the card was asked for twice. Asking is now
  debounced per app (2 s).
- **`hyprctl repl` answers `unknown request` when the Lua returns an empty string**, which is why
  `vault.hidden()` is read wrapped in brackets.
- **Zen sets no Wayland idle inhibitor while it plays** (`inhibiting_idle` stayed `false` during a
  Twitch stream, 04/11/2026), so Hyprland cannot tell a playing window apart. MPRIS can: the
  player reports `DesktopEntry "zen"`, which the `^zen` pattern already matches.
- **`misc.focus_on_activate` is off**, so clicking a hidden app in the launcher or tray only
  marks it urgent instead of focusing it. Urgency is NOT a trigger, because a Discord message marks
  it urgent too and the card would pop up on every message. SUPER+CTRL+V is the way back.

## Apps that have their own lock

Turn these on inside the app, in addition to the vault. They are app settings, not Nix:

- **WhatsApp (zapfast)**: its own lock is enough, so it is NOT a vault app (removed 04/11/2026).
  Two password prompts in a row for one app were noise.

- **Telegram Desktop**: Settings > Privacy and Security > Local passcode, with auto-lock after
  5 minutes away. It locks the chats themselves, not just the window.
- **Bitwarden**: Settings > Vault timeout. The rbw side already locks after an hour
  (`lock_timeout`, [`modules/nixos/core/secrets.nix`](../../../modules/nixos/core/secrets.nix)).
- **Zen**: the primary password plus the Zen guard, which closes it a few minutes into a session
  lock ([`../apps/zen.md`](../apps/zen.md)). The vault adds the unfocused case on top.

## Inspiration

Android's App Lock and Samsung's Secure Folder (an app behind a PIN while the phone stays usable),
iOS 18's "Require Face ID" per app, and the password managers' auto-lock on inactivity. This is
the desktop version of those, minus their isolation: here the apps share the session.
