# Vicinae: the launcher, the clipboard history and the command palette

`modules/home/desktop/vicinae/`. One Raycast-style window on SUPER+Q for apps, files, the
calculator, the clipboard history, my own commands and a few extensions. It replaced rofi (four
UIs, each with its own `.rasi`) and cliphist (a second history watcher) on 13/10/2026.

## Why Vicinae

Rofi was four separate tools sharing one binary: the drun launcher, the `run` mode on SUPER+R, a
cliphist picker that built image thumbnails in a shell loop, and the cheatsheet. Each had its own
theme file and none of them knew about the others. Vicinae does all of that in one process, with a
real clipboard manager (images, search, pins, encryption, eviction) instead of a picker over
cliphist, plus file search, a calculator and script commands, which rofi never had.

The choice of Vicinae was mine before this migration; other launchers were not benchmarked against
it, so this note does not claim it beats them. What was checked is that it fits here: native
Wayland (layer shell), C++/Qt like the rest of the desktop's Qt stack, packaged in nixpkgs with a
Home Manager module, and an extension API that is Raycast's, so its extensions are ports of
maintained Raycast ones.

## What it replaced, and what stays independent

| Was | Is now |
| --- | --- |
| rofi `drun` on SUPER+Q | Vicinae (`vicinae toggle`) |
| rofi `run` on SUPER+R | gone: apps, script commands and file search on SUPER+Q cover it |
| cliphist plus the rofi picker on SUPER+SHIFT+V | Vicinae's clipboard history (`vicinae://launch/clipboard/history`) |
| the cheatsheet in rofi on SUPER+H | the same parser, shown in `vicinae dmenu` ([desktop-plumbing.md](desktop-plumbing.md)) |
| the Zen guard's rofi password field | `zenity --password` ([zen.md](../apps/zen.md)); a searchable launcher is the wrong place to type a password |
| rofi's drun cache in usage-audit | Vicinae's visit tracker ([usage-audit.md](../repo/usage-audit.md)) |

Independent on purpose: `clipboard-push` and kitty's smart paste (putting the clipboard on ANOTHER
machine is not a history feature), `wl-clip-persist` (Vicinae records the history but does not own
the selection when the source app exits), Blueman (the extension below has no pairing agent),
Quickshell, hyprlock and the `vpn` CLI. The binds for those are unchanged.

## How it is installed

Home Manager's own `programs.vicinae` module (release-26.05) with `pkgs.unstable.vicinae`, because
26.05 ships 0.23 and the features below need 0.29. The binary comes from cache.nixos.org, so there
is no Vicinae flake input and no extra substituter. Upstream's flake was the alternative: one
version newer, but it wants its own nixpkgs plus vicinae.cachix.org, or a local Qt build per bump.

The unit is Home Manager's (`vicinae server`, `Restart=always`, wanted by
`graphical-session.target`), extended with the repo's session conventions: `ConditionEnvironment =
WAYLAND_DISPLAY` and `Slice = session.slice`, the same as `polkit-agent.nix`. It is the only
starter (rule 15): nothing in `autostart.lua` launches it.

No `vicinae-input-server`. Pasting straight into the focused app and snippet keyword expansion
both need it, and it is a capability binary (`cap_dac_override`) that reads every keyboard and
writes to `/dev/uinput`. That is a keylogger-shaped privilege for a convenience, so selecting an
entry COPIES it, and Ctrl+V pastes. `input_server.enabled = false` says so in the settings, so
Vicinae does not try to spawn a binary that is not there.

## Settings stay writable

`programs.vicinae.settings` is left empty on purpose: it would turn
`~/.config/vicinae/settings.json` into a read-only store link, and Vicinae writes that file from its
own settings window. The declared values go in a store JSON passed through `VICINAE_OVERRIDES` on
the unit instead. The server merges those files AFTER `settings.json` (verified in 0.29.0's
`src/server/src/config/config.cpp`), so the repo wins on every key it declares and the GUI keeps
working for the rest. Changing a declared key in the GUI does nothing lasting: the override wins at
the next start, which is the point.

What is declared, and why:

| Setting | Value | Why |
| --- | --- | --- |
| `telemetry.system_info` | `false` | no report of my machine to anyone |
| `favicon_service` | `none` | no favicon lookups through a third party for every URL |
| `input_server.enabled` | `false` | see above |
| `tray.enabled` | `false` | the bar's tray has no use for it |
| `close_on_focus_loss` | `false` | see below: `true` closed it within 92 ms of opening |
| `pop_to_root_on_close` | `true` | it reopens on the search, not on the last view |
| `escape_key_behavior` | `close_window` | Esc closes, like rofi did |
| `launcher_window.layer_shell.keyboard_interactivity` | `on_demand` | `exclusive` breaks popup mouse handling on Hyprland |
| `providers.calculator.preferences.backend` | `qalculate` | libqalculate: units, currencies, the GTK Qalculate! engine |
| `search_files_in_root`, `fallbacks` | `true`, `files:search` | files show up in the main search |
| `launcher_window.size`, `font.normal.size` | 1000x620, 11.5 | the 770x480 default felt small on a 1440p panel |

## The clipboard

`providers.clipboard.preferences`, keys read from 0.29.0's `clipboard-extension.cpp`:

- **Encryption**: `encrypt_sensitive_data = true`. It is OFF by default on Linux (on by default
  on macOS and Windows). The history is AES-256-GCM, and the master key is stored in the Secret
  Service under `vicinae-master-key`. Here that is gnome-keyring, unlocked from the TPM at login
  ([desktop.md](desktop.md)) and started by D-Bus activation, so the first access starts it. If
  the keyring is ever locked or missing, the server stops with "Database keychain unavailable" and
  restarts in a loop: `vicinae logs` shows it, and `keyring-tpm-seal` is the usual fix.
- **Retention**: `evictionThreshold = "2592000"`, 30 days. `preserveTagged = true` keeps pinned
  and tagged entries past it.
- **Passwords**: `ignorePasswords = true` drops any offer carrying `x-kde-passwordManagerHint`
  (KeePassXC, the Bitwarden desktop app), and an offer carrying `vicinae/concealed` is always
  dropped. 0.29.0 has no per-app ignore list yet (`ignoredApps` exists only on main).
- **Images**: kept and previewed. Pinning and tagging (Ctrl+E) are built in.

cliphist's old database in `~/.cache/cliphist` was left on disk, untouched: removing a package is
not permission to delete its data. Delete it by hand when it is no longer wanted.

## File search

Only named folders are indexed: Desktop, Documents, Downloads, Pictures, Music, Videos, Projects
and Archive. Indexing `$HOME` and excluding the bad parts would be a deny list, and a deny list
misses the next dot directory with a key in it; an allow list cannot. The dot directories (`~/.ssh`,
`~/.gnupg`, the browser profiles, `~/.config/sops`, the keyrings), the mounts (`~/FAI-workstation`,
`/mnt/windows`) and the bulk (`~/.local/share/Steam`, bottles) are never walked. Inside the allowed
folders the indexer already skips `.git`, `node_modules`, `.venv`, `__pycache__`, `.cache` and any
directory with a `CACHEDIR.TAG` (0.29.0's `entry-filter.cpp`). The index lives in
`~/.cache/vicinae/file-indexer/`.

## The theme

`themes.palette` is generated from `my.theme.palette`, so a `my.theme.name` switch plus a rebuild
recolors it like every other consumer, and both the dark and the light slot point at it. Stylix's
own Vicinae target is off: its base16 mapping has no slot for `border`. The built-in commands draw
their icon on a tile filled with one of the `accents` (Clipboard red, Files orange...), hardcoded
per command; at full strength those were loud blocks next to the Win11 app icons, so the accents
are the palette's colors at 20 % opacity, which leaves soft tinted chips under a light glyph. The font is `my.fonts.ui`
and the icons are `my.theme.iconTheme`.

| Vicinae key | Palette key |
| --- | --- |
| `core.background`, `core.secondary_background` | `bg`, `surface` |
| `core.foreground`, `text.muted`, `text.placeholder` | `text`, `subtext`, `dim` |
| `core.accent`, `main_window.border`, `input.border_focus` | `accent` |
| `core.border`, `input.border` | `border` |
| `list.item.selection.background` | `track` |
| `accents.*` | the palette's named colors at 20 % opacity |
| `text.danger`, `text.success` | `red`, `green`, solid |

## Shortcuts

| Keys | What |
| --- | --- |
| SUPER+Q | toggle Vicinae (also the MX Master's gesture button click, which sends SUPER+Q) |
| SUPER+SHIFT+V | the clipboard history, directly |
| SUPER+H | the keybind cheatsheet |
| SUPER+ALT+V | `clipboard-push` (unchanged) |

Vicinae binds nothing globally itself: on Hyprland its global shortcuts need a protocol Hyprland
does not have, so every key above is a `hl.bind` in `keybinds.lua`, and there is nothing to overlap.

## Script commands

`scripts.nix`. Each command is a `writeShellApplication` (so shellcheck runs at build time) whose
text starts with Vicinae's `@vicinae.*` header, linked into `~/.local/share/vicinae/scripts/`, the
directory Vicinae scans and watches. They call the existing CLIs by name, the same as
`keybinds.lua` does, so nothing is reimplemented:

| Group | Commands |
| --- | --- |
| VPN | Connect FAI, Connect UFSCar, Disconnect (`vpn connect`/`disconnect`, compact mode shows its answer) |
| Desktop | SSH: FAI workstation (kitty), Restart Quickshell, Shuffle wallpapers, Lock session, Show keybind cheatsheet |
| System | NixOS rebuild: `needsConfirmation`, then a visible kitty running `rebuild`, so nh's sudo prompt and the log stay in front of me |
| Links | FAI Dashboard, GitHub, dotfiles on GitHub, dotfiles in VS Code |

To add one, add an entry to the list in `scripts.nix` (`name`, `title`, `group`, optional `mode`
and `confirm`). `vicinae script check <file>` validates a header; it prints nothing for a good one
and the error for a bad one, and it exits 0 either way, so read its output. All thirteen passed on
13/10/2026.

## Extensions

`extensions.nix`, from the `vicinae-extensions` flake input (`github:vicinaehq/extensions`,
`flake = false`), built with Home Manager's `config.lib.vicinae.mkExtension`. It uses
`importNpmLock`, which reads each extension's `package-lock.json`, so bumping the input needs no
hash edit.

| Extension | What it adds | Credentials |
| --- | --- | --- |
| nix | nixpkgs packages and options, Home Manager options | none |
| systemd | list, start, stop and restart units | none |
| bluetooth | power, scan, connect, battery | none; Blueman stays as the BlueZ pairing agent, which the extension does not register |
| github | issues, PRs, workflow runs, repo search | a personal access token |

Not installed: everything the desktop already does (audio, power profiles, wifi) and anything
without a clear use. Each extension is a TypeScript build to keep working, so four with a reason
beat twenty because they exist.

**systemd and bluetooth drop `usocket` from their lock.** dbus-next lists it as an OPTIONAL native
module for abstract sockets, and it pins node-gyp 7, which dies on Node 24 ("Completion callback
never invoked"); upstream's own flake skips these two extensions for that reason. `--omit=optional`
was tried and also drops esbuild's platform binary, so only `usocket` goes, through a patched
`packageLock` handed to `importNpmLock`. The system and session buses are path sockets, so the
abstract-socket branch is never taken.

To add one, put its folder name in the list; if its tsconfig extends the repo root or it needs a
native module, see how upstream's `flake.nix` builds it first.

### The GitHub token

The extension's `personalAccessToken` is a password preference. Vicinae reads the merged config
before its own database for those (`root-item-manager.cpp`), so the token arrives as one more
override file, rendered by sops-nix into `/run/secrets/rendered/vicinae-github.json` (owner me,
0400) and appended to `VICINAE_OVERRIDES`. The store only ever holds sops's placeholder (checked
by evaluating the template on 13/10/2026).

Until the token exists the template is not declared and the extension asks for it in its own form.
To turn it on:

1. Create a classic token at GitHub, scopes `repo`, `notifications`, `project`, `read:org`,
   `read:user`, and save it in Bitwarden as **Vicinae GitHub Token**.
2. Add `"vicinae_github_token": "Vicinae GitHub Token"` to `secrets/bitwarden-secrets.json`.
3. `sync-secrets`, then `rebuild`. `modules/nixos/core/secrets.nix` declares the template once the
   key exists in both places, and the Vicinae unit restarts with it.

## The browser

The Vicinae add-on (`firefox@vicinae.com`, signed, on AMO) talks to the server through native
messaging. The nixpkgs build writes the host manifest itself at every start, into
`~/.mozilla/native-messaging-hosts/` and, because `~/.zen` exists, into
`~/.zen/native-messaging-hosts/`. Nothing in Zen's policies or signature checks changes: the add-on
is installed by hand from AMO inside Zen, once. The manifests were there after the first start on
13/10/2026, pointing at the store's `vicinae-browser-link`; they are rewritten at every start, so a
version bump repoints them. Tabs showing up in Vicinae once the add-on is in is NOT verified yet.

## Debugging

```text
systemctl --user status vicinae      # the unit
vicinae logs -f                      # the server's own log
vicinae ping                         # is the server answering
vicinae cmd ls --json                # every indexed command, scripts and extensions included
```

The state lives in `~/.local/share/vicinae/` (the clipboard database and blobs, `vicinae.db`,
`metadata.json` with the visit counts, `snippets/`, `shortcuts/`, the extensions and the scripts)
and the file index in `~/.cache/vicinae/`.

**Why it does not close when focus leaves.** With `close_on_focus_loss = true`, SUPER+Q showed the
window for a blink and it was gone: on 13/10/2026 Hyprland's event socket showed `openlayer>>vicinae`
then `closelayer>>vicinae` 92 ms later, with the active window never leaving Zen. The server gets a
focus-out right after the layer maps and obeys it. `exclusive` keyboard interactivity did not help
(gone in 157 ms); only `false` keeps it open, which is also upstream's default. Esc, SUPER+Q again,
or running an entry closes it.

Two upstream quirks seen on 0.29.0, both harmless here:

- `Circular import detected for <overrides>.json, ignoring` at every start. `load()` recurses into
  the override file, which then finds itself in its own override list; the top-level merge already
  happened, which the encrypted databases prove.
- `vicinae close` hangs when the window open is a `dmenu` session (the cheatsheet). Nothing here
  calls it; Esc and the binds close it fine.

## Runtime checks (13/10/2026, right after the switch)

Measured on this machine (ex-b560m-v5, Hyprland 0.55.4, Vicinae 0.29.0), with my session in use:

| Check | Result |
| --- | --- |
| `vicinae toggle` x10, open / close | 10 of 10 worked; open 11-21 ms in 8 runs and about 1 s twice; close 15-30 ms, once 940 ms |
| memory, PSS | server 248 MiB, extension runtime (node) 73 MiB, file indexer 86 MiB, data-control 2 MiB |
| idle CPU, 60 s | 66 ms, 0.11 % of one core |
| first index | `~/Projects` in 66 s, 1493 directories watched; the cgroup held 696 MiB of reclaimable file cache after it |
| encryption | `clipboard.db` and `vicinae.db` no longer start with the SQLite header |
| image history | a PNG copied by a process that then exited was recorded and still pasted (wl-clip-persist) |
| passwords | an offer with `x-kde-passwordManagerHint` was logged "Ignored password clipboard selection" |
| commands | `vicinae cmd ls` lists the 13 scripts and the four extensions' commands |
| cheatsheet | opened from the real `keybinds-cheatsheet` and exited 0 |
| theme | Tokyo Night background and accent, JetBrains Mono and the Win11 icons, by screenshot |

Not compared with rofi: rofi was not running as a server, so there is no fair "lighter" number,
and this note does not claim one. Still to check by hand: the calculator and file search typed in
the window, each script command run once (the VPN ones need the network), `clipboard-push
workstation` with the VPN up, the Zen guard with the real dialog after a lock, the GitHub
extension once the token exists, and the browser add-on.
