# The app vault: sensitive apps ask for the password again after a lock

The session lock covers leaving the desk: hypridle locks after 5 minutes
([`lockscreen.md`](lockscreen.md)). The vault is a second layer behind it. When the session locks,
every sensitive app is hidden, so whoever gets past the lock screen still meets a password per
app, the way Android's App Lock behaves. While the PC is in use nothing hides.

## What it is, and what it is not

A speed bump against a curious passer-by, the same model as the Zen guard
([`../apps/zen.md`](../apps/zen.md)). It is NOT a security boundary: anyone at an unlocked
session with a terminal can run `hyprctl eval 'vault.release("discord")'` or open
`special:vault`, and the apps' data on disk is untouched. For real protection the screen lock is
the boundary, and an app's own lock is the second one where it has one (see the end).

The apps are hidden, never closed: they keep running, notifying and playing audio.

## How it works

Two halves, joined by IPC:

| Part              | File                                                                                                                                                                    | Job                                                                             |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| The hiding        | [`hypr/lua/vault.lua`](../../../modules/home/desktop/hypr/lua/vault.lua)                                                                                                | which classes count, moving windows to `special:vault` and back                 |
| The password card | [`quickshell/Vault.qml`](../../../modules/home/desktop/quickshell/Vault.qml), [`vault/VaultPrompt.qml`](../../../modules/home/desktop/quickshell/vault/VaultPrompt.qml) | which apps it asks for, the PAM conversation, calling `vault.release(app)` back |

- **The session lock** hides every open vault app first: `lockscreen.service` runs
  `hyprctl eval 'vault.lock_all()'` as an `ExecStartPre` prefixed with `-`, so a failure there never
  keeps the screen from locking. Every lock goes through that unit: SUPER+L, the idle, the boot.
- **Apps with no window are marked too.** Discord lives in the tray with its window closed, so
  without this whoever unlocked the screen reopened it from the tray with no password. Now the
  first window an app opens after a lock goes straight to the vault and asks. That mark lives only
  in the Lua state, so a `hyprctl reload` while the screen is locked clears it for apps that have no
  window.
- **Hiding** moves every window of the app to `special:vault` with `follow = false`, after
  tagging it `vault_from_<workspace>`. The tag lives on the window, so it survives a
  `hyprctl reload` (the Lua state does not; measured 04/11/2026) and dies with it.
- **Coming back** puts each window on the workspace in its tag and focuses the one used last.
  Floating, position, size and fullscreen survive the round trip, and so does the monitor, because
  `monitors.lua` pins each workspace to one (tested 04/11/2026 with a fullscreen window and a
  floating one on the secondary monitor; the floating one may shift a few pixels). A window with no
  tag lands on the active workspace.
- **Getting them back.** SUPER+CTRL+V asks for everything hidden at once. Focusing a hidden window
  (alt-tab, a stray dispatch) or a hidden app opening a new window puts it back in the vault and
  runs `qs ipc call vault ask <app>`. SUPER+CTRL+L hides them by hand without locking.
- **The card** reuses the lock's [`lock/Auth.qml`](../../../modules/home/desktop/quickshell/lock/Auth.qml)
  on its OWN PAM service, `quickshell-vault`, so its password is NOT the login one (see below). It
  sits on the focused monitor only, over a dim scrim, with exclusive keyboard focus. Esc or a click
  outside cancels and the apps stay hidden. Three misses in a row wait 30 s.
- **After `hyprctl reload`** the Lua table starts empty, so anything already in `special:vault`
  counts as hidden again.
- **To see the state**: `hyprctl repl 'return vault.status()'` prints each open app as `hidden`
  or `open`.

### The apps

The classes are Lua patterns over the lowercased window class, because X11 and Wayland report
different ids for the same app:

| App                                 | Classes                                   |
| ----------------------------------- | ----------------------------------------- |
| Discord                             | `discord`, `vesktop`                      |
| Telegram                            | `TelegramDesktop`, `org.telegram.desktop` |
| ChatGPT (the `chatgpt-web` web app) | `chatgpt`                                 |
| Obsidian                            | `obsidian`, `md.Obsidian`                 |
| Zen                                 | `zen*`                                    |
| LibreWolf                           | `librewolf`                               |

Adding an app is one line in `APPS` (vault.lua) plus its name and icon in `Vault.qml`. The `.lua`
is hot-reloaded, so `hyprctl reload` applies it with no rebuild.

## The vault's own password

A second password is the point: someone who learned the login one still stops at the apps.

- **Where it lives**: the Bitwarden item `App Vault Password` (its password field), mapped to the
  sops secret `vault_password` in `secrets/bitwarden-secrets.json` and readable by the user at
  `/run/secrets/vault_password` ([`../repo/secrets.md`](../repo/secrets.md)).
- **How it is checked**: `security.pam.services.quickshell-vault` in
  [`modules/nixos/desktop/desktop.nix`](../../../modules/nixos/desktop/desktop.nix) is just
  `pam_exec expose_authtok` running `vault-check`, which compares the typed password with that
  file. nixpkgs has no `pam_pwdfile`, and `pam_exec` ships with linux-pam itself.
- **Fails closed**: with no secret synced yet, every attempt is refused. The way out then is
  `hyprctl eval 'vault.release("<app>")'` from a terminal.
- **Setting or changing it**: run `vault-passwd`
  ([`modules/nixos/desktop/scripts/vault-passwd.sh`](../../../modules/nixos/desktop/scripts/vault-passwd.sh)). It asks
  for the new password twice, writes it IN BITWARDEN, then runs `sync-secrets` and the switch.
  Before the first switch it is not installed yet: `nix develop -c bash` on the script does the
  same. A hand edit of the sops file is undone by the next sync.

Tested 04/11/2026 through a throwaway Quickshell `PamContext` on a temporary `pam.d`: the right
password SUCCESS, a wrong one FAIL. The checker alone also refuses an empty password, a trailing
space and a missing secret.

## Why only on lock (04/11/2026)

The first version also hid an app after 5 minutes unfocused, like a password manager's vault
timeout. In daily use it fought the person at the desk: a stream watched on the other monitor has
no focus, so it vanished mid-video, and keeping it took an MPRIS bridge (Zen sets no Wayland idle
inhibitor while it plays). The rule became the one asked for: lock only when nobody is using the
PC, and the screen lock already decides that. The grace clock and the MPRIS bridge were removed.

## Pitfalls found while building it

- **Focusing a window in a special workspace OPENS that special** on its monitor, so the hidden app
  showed up on screen the moment anything focused it. `close_view()` closes it again. Since
  `toggle_special` only acts on the FOCUSED monitor, it first focuses each monitor that shows the
  vault (measured 03/11/2026: a bare toggle opened the vault on the other monitor instead).
- **One reach fired two `window.active` events**, so the card was asked for twice. Asking is now
  debounced per app (2 s).
- **A plain move out of the vault snaps back.** While an app counts as hidden, focusing any of its
  windows re-hides it, so `hyprctl dispatch` moving it out does nothing visible. Only
  `vault.release(app)` clears the mark.
- **`hyprctl repl` answers `unknown request` when the Lua returns an empty string**, which is why
  `vault.hidden()` is read wrapped in brackets.
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
  lock ([`../apps/zen.md`](../apps/zen.md)).

## Inspiration

Android's App Lock and Samsung's Secure Folder (an app behind a PIN while the phone stays usable),
iOS 18's "Require Face ID" per app, and the password managers' auto-lock. This is the desktop
version of those, minus their isolation: here the apps share the session.
