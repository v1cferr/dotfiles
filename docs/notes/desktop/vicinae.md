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
26.05 ships 0.23 and the features below need 0.29. There is no Vicinae flake input and no extra
substituter. Upstream's flake was the alternative: one version newer, but it wants its own nixpkgs
plus vicinae.cachix.org. Since 14/10/2026 the package carries two patches, a one-line one for the
icons (see [the theme](#the-theme)) and the thumbnail backend (see [File search](#file-search)),
plus the pinned `pactl` (see [Extensions](#extensions)) since 15/10/2026, so it is built here instead of coming from cache.nixos.org: 9 min 16 s on
ex-b560m-v5 (12 threads, 14/10/2026), Qt dev outputs fetched from the cache, on every unstable bump
that touches it.

The unit is Home Manager's (`vicinae server`, `Restart=always`, wanted by
`graphical-session.target`), extended with the repo's session conventions: `ConditionEnvironment =
WAYLAND_DISPLAY` and `Slice = session.slice`, the same as `polkit-agent.nix`. It is the only
starter (rule 15): nothing in `autostart.lua` launches it.

Apps it launches go through `app2unit --` (`applications.preferences.launchPrefix`), so each one
gets its own `app-Hyprland-<name>-<random>.scope` under `app.slice`. Without it they were children
in `vicinae.service`'s cgroup (seen on 15/10/2026: Zen and VS Code there). Nothing died on a
restart, since the unit kills only the main process, but their memory counted as Vicinae's and
`systemctl --user status vicinae` listed every Zen tab. Left empty, the prefix is auto-detected only
under uwsm, which this session (LightDM, plain Hyprland) does not run.

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
| `favicon_service` | `google` | tab and shortcut icons; see [the browser](#the-browser) for what leaves |
| `input_server.enabled` | `false` | see above |
| `tray.enabled` | `false` | the bar's tray has no use for it |
| `close_on_focus_loss` | `false` | see below: `true` closed it within 92 ms of opening |
| `pop_to_root_on_close` | `true` | it reopens on the search, not on the last view |
| `escape_key_behavior` | `close_window` | Esc closes, like rofi did |
| `launcher_window.layer_shell.keyboard_interactivity` | `on_demand` | `exclusive` breaks popup mouse handling on Hyprland |
| `providers.calculator.preferences.backend` | `qalculate` | libqalculate: units, currencies, the GTK Qalculate! engine |
| `search_files_in_root`, `fallbacks` | `true`, `shortcuts:dotfiles-google` then `files:search` | files show up in the main search; a query that matches nothing offers Google |
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

**The cliphist history was ported, then deleted (13-14/10/2026).** Vicinae has no import, so a COPY
of cliphist's db was replayed through the clipboard, oldest first, with `wl-copy` and a 0.25 s pause
per entry for the watcher to record it. Of 500 entries, 468 went in (405 texts, 56 PNGs, 7 copied
files); 32 texts were skipped because they looked like secrets (a single 16-64 character token, or
a `password`, `secret`, `token` or `senha` followed by `:` or `=`), since cliphist never filtered
passwords and these would have stayed searchable for 30 more days. Every ported entry carries the
import date, not its original one. After I checked old entries in SUPER+SHIFT+V,
`~/.cache/cliphist` (272 MB: a 64 MB bbolt db that never shrinks plus 208 MB of thumbnails, most
of them orphans) and rofi's three cache files were deleted. A package leaving is not permission to
delete its data; my explicit go-ahead was.

## File search

Only named folders are indexed: Desktop, Documents, Downloads, Pictures, Music, Videos, Projects
and Archive. Indexing `$HOME` and excluding the bad parts would be a deny list, and a deny list
misses the next dot directory with a key in it; an allow list cannot. The dot directories (`~/.ssh`,
`~/.gnupg`, the browser profiles, `~/.config/sops`, the keyrings), the mounts (`~/FAI-workstation`,
`/mnt/windows`) and the bulk (`~/.local/share/Steam`, bottles) are never walked. Inside the allowed
folders the indexer already skips `.git`, `node_modules`, `.venv`, `__pycache__`, `.cache` and any
directory with a `CACHEDIR.TAG` (0.29.0's `entry-filter.cpp`). The index lives in
`~/.cache/vicinae/file-indexer/`.

### Previews

Stock 0.29 previews only images and text: everything else gets its file-type icon. Upstream has
an image type for this, `FileThumbnail`, but only a macOS backend (Quick Look); on Linux it fell
through to the fallback. `file-thumbnails.patch` (14/10/2026) adds the Linux backend, on the
[freedesktop thumbnail spec](https://specifications.freedesktop.org/thumbnail-spec/latest/):

- A valid entry in `~/.cache/thumbnails/{normal,large,x-large,xx-large}` (name = MD5 of the file
  URI, `Thumb::MTime` equal to the file's) is used as is. Dolphin writes the same cache, so what
  it already previewed shows up with no work.
- On a miss it generates one: `ffmpegthumbnailer` for `video/*`, `pdftoppm` (first page) for PDF,
  as Nix store paths substituted in `postPatch`. It stores the result in the cache (0600, atomic),
  where Dolphin reuses it, and a failure goes to `fail/vicinae/` so a broken file is not retried
  on every selection.
- It runs on its own 2-thread pool with a 10 s timeout per file, so a slow generator never holds
  up icon rendering; the preview fills in when it finishes, or falls back to the file-type icon.

Office documents still get the icon: a generator for them means LibreOffice. The patch is meant
to go upstream as the Linux side of
[issue #2079](https://github.com/vicinaehq/vicinae/issues/2079); once it lands, drop it here.

## The theme

`themes.palette` is generated from `my.theme.palette`, so a `my.theme.name` switch plus a rebuild
recolors it like every other consumer, and both the dark and the light slot point at it. Stylix's
own Vicinae target is off: its base16 mapping has no slot for `border`. The built-in commands draw
their line icon on a tile filled with one of the `accents` (Clipboard red, Files orange...),
hardcoded per command. No theme key reaches the tile alone: the same `accents` color the alert's
warning icon and confirm button, syntax highlighting, script ANSI output and extension tags, so
dimming them (20 % here until 14/10/2026) dimmed all of those too. The accents are therefore the
palette's colors at full strength, and a `postPatch` empties the return in `resolveBackgroundTint`
(`image-stream.cpp`), so the built-in icons render as bare line glyphs in the text color, like the
[script icons](#script-commands). `--replace-fail` breaks the build if an upstream bump moves that
line: then adjust or drop the substitution. The font is `my.fonts.ui`
and the icons are `my.theme.iconTheme`. The frame follows Vicinae's own clipboard screenshot, the
look I asked for on 14/10/2026: a 1 px outline at half strength instead of the 2 px accent ring,
and dividers in `track`, one step above the surface, so the panes separate without lines that
draw the eye.

| Vicinae key | Palette key |
| --- | --- |
| `core.background`, `core.secondary_background` | `bg`, `surface` |
| `core.foreground`, `text.muted`, `text.placeholder` | `text`, `subtext`, `dim` |
| `core.accent`, `input.border_focus` | `accent` |
| `main_window.border` (1 px) | `border` at 50 % opacity |
| `core.border` (the dividers), `input.border` | `track` |
| `list.item.selection.background` | `track` |
| `accents.*` | the palette's named colors |
| `text.danger`, `text.success` | `red`, `green`, solid |

## Shortcuts

| Keys | What |
| --- | --- |
| SUPER+Q | toggle Vicinae (also the MX Master's gesture button click, which sends SUPER+Q) |
| SUPER+SHIFT+V | the clipboard history, directly |
| SUPER+H | the keybind cheatsheet |
| SUPER+ALT+V | `clipboard-push` (unchanged) |
| SUPER+R | Repositories |
| SUPER+K | VS Code's recent projects |
| SUPER+SHIFT+E | the emoji picker |
| SUPER+SHIFT+P | the Bitwarden vault |

Vicinae binds nothing globally itself: on Hyprland its global shortcuts need `ext-hotkey-v1`, a
protocol Hyprland has not merged, so every key above is a `hl.bind` in `keybinds.lua`, and there is
nothing to overlap. A key for one command is a deeplink, `vicinae
'vicinae://launch/<provider>/<entrypoint>?toggle=true'` (an extension's provider is its
`@author/name`); `toggle` closes the window when it is already open, so the same key dismisses it.

**Aliases and favorites** are overrides in `default.nix`. An alias puts its command first as soon
as the search starts with it, above any score: `rep` (Repositories), `rec` (VS Code recents),
`dot` (the dotfiles in VS Code), `vol` (output devices), `bw` (the Bitwarden vault). The favorites, shown on the empty root, are
the clipboard history, Repositories and VS Code recents.

## URL shortcuts

Vicinae's [shortcuts](https://docs.vicinae.com/shortcuts) are URL templates with arguments, opened
in a chosen app. `shortcuts.nix` declares them, each opened in Zen by its desktop id `zen-beta`
with its site's favicon as icon:

- **Search Google** and **Search YouTube**.
- **Search Nix packages**: search.nixos.org on the channel this system builds from,
  `system.nixos.release` (the `nix` extension searches the same index inside Vicinae).

A shortcut with exactly one argument can be a fallback, and Google is first in `fallbacks`: typing
anything that matches nothing offers it at the bottom. Only Google, because a list of three sites
under every miss is noise. The GitHub and GitLab searches were here for a day; the
[Repositories](#repositories) extension replaced them with a list.

0.29.0 keeps them in `~/.local/share/vicinae/shortcuts/shortcuts.json` and REWRITES that file on
every open (the counters, `shortcut-db.cpp`), and only reads it at start. So it cannot be a store
link: a Home Manager activation step merges the declared entries in by their fixed ids, keeping
their counters, and leaves the ones made in the GUI alone. It runs before `reloadSystemd`, and the
declared JSON is in the unit's `X-Restart-Triggers`, so a change restarts the server onto the merged
file. Every `dotfiles-*` id is owned by the declaration: one removed here is removed from the file
too. A shortcut deleted in the GUI comes back at the next switch; remove it here instead.

Caveat, from `expandShortcut` in `shortcut-actions.hpp`: the argument is pasted into the URL
WITHOUT percent-encoding. Spaces are fine (the browser encodes them), but a `+`, `&` or `#` in the
query changes what Google receives (`c++` arrives as `c` and two spaces).

## Script commands

`scripts.nix`. Each command is a `writeShellApplication` (so shellcheck runs at build time) whose
text starts with Vicinae's `@vicinae.*` header, linked into `~/.local/share/vicinae/scripts/`, the
directory Vicinae scans and watches. They call the existing CLIs by name, the same as
`keybinds.lua` does, so nothing is reimplemented:

| Group | Commands |
| --- | --- |
| VPN | Connect FAI, Connect UFSCar, Disconnect (`vpn connect`/`disconnect`, compact mode shows its answer) |
| Desktop | SSH: FAI workstation (kitty), Restart Quickshell, Shuffle wallpapers, Lock session, Away screen, Show keybind cheatsheet, RGB lights on/off (`rgb-lights`), Reload Hyprland |
| Screenshot | Select an area (`flameshot gui`), Main monitor, Second monitor (`flameshot-screen <monitor>`, to the clipboard), each 0.3 s after the window closes so Vicinae is not in the shot |
| Night light | Toggle, Natural colors, 3000K, 2000K: the same commands SUPER+F9 and its modifiers run |
| Notifications | Toggle do not disturb, Clear (`qs ipc call notif dnd`/`clear`) |
| Hosts | Wake the FAI workstation, RDP: T480; both in a kitty that stays open, since they talk back (freerdp asks for the password there) |
| Downloads | Download a MEGA link: an argument field for the link, then `mega-dl` in kitty |
| System | NixOS rebuild: `needsConfirmation`, then a visible kitty running `rebuild`, so nh's sudo prompt and the log stay in front of me |
| Links | FAI Dashboard, GitHub, dotfiles on GitHub, dotfiles in VS Code |

**Their icons are JetBrainsMono Nerd Font glyphs**, the UI font, cut out at build time as SVGs in
the palette's `text` color (fonttools, one `runCommand` per glyph) and named in the header with
`@vicinae.icon <store path>`. They are looked up by glyph NAME (`md-lock_outline`, `linux-nixos`),
so a name the font does not have fails the build instead of showing a blank. The `_outline`
variants are used where Material Design has one, to match the thin strokes of Vicinae's own icons.
Only my scripts can do this: the built-in commands' icons are SVGs compiled into Vicinae, and it
only accepts a text glyph as an icon when the glyph is in its Unicode/emoji table, which the Nerd
Font private-use range is not. Replacing those would mean patching Vicinae and building it locally
on every bump, so they stay.

To add one, add an entry to the list in `scripts.nix` (`name`, `title`, `group`, `glyph`, optional `mode`,
`confirm` and `arguments`, a list of placeholders that become `@vicinae.argumentN` text fields and
reach the script as `$1`, `$2`...). `vicinae script check <file>` validates a header; it prints nothing for a good one
and the error for a bad one, and it exits 0 either way, so read its output. All 29 passed on
16/10/2026.

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
| bitwarden | search the vault and copy a password, username, TOTP or URL, through `rbw` | my Bitwarden account, unlocked by `rbw` (below) |
| ssh | the hosts of `~/.ssh/config` (`ssh.nix`), opened as `kitty ssh <host>` | none; the keys are the agent's |
| zoxide-recent-directories | zoxide's directories by frecency; Enter opens VS Code, the alternative action Dolphin | none |
| timer | timers in plain words ("25m Pomodoro"), each a transient `systemd-run --user` timer that ends in `notify-send` | none |
| reminders | one-off and recurring reminders in plain English ("call the dentist tomorrow at 10"), with Complete and Snooze buttons on the notification | none |
| ollama-wordsmith | Translate, Summarize, Explain, Enhance and Dictionary with the local Ollama: type or paste the text in the search bar | none; Ollama on localhost |
| vscode-recents | VS Code's File > Open Recent list (folders, files, SSH remotes); Enter opens it in VS Code | none |
| pulseaudio | output and input devices (default, mute, volume in 5% steps or exact), per-app playback and recording streams, card profiles | none |
| repositories (mine) | my GitHub accounts and FAI's GitLab in one list | the GitHub token above, FAI's `read_api` token |

Not installed: everything the desktop already does (power profiles, wifi) and anything without a
clear use. Audio was on that list until 15/10/2026: the bar and pavucontrol (SUPER+S) cover it, but
from the launcher it takes typing a word instead of reaching for the mouse. Media needs no
extension: Vicinae's built-in `media` group already has Play / Pause, Next and Previous Track, Now
Playing (over MPRIS on D-Bus), Turn Volume Up/Down, Set Volume to 0/25/50/75/100% and Toggle Mute.
player-pilot was installed for an hour and dropped for that reason; it had no play/pause toggle. Each extension is a TypeScript build to keep working, so a few with a reason
beat twenty because they exist.

**systemd and bluetooth drop `usocket` from their lock.** dbus-next lists it as an OPTIONAL native
module for abstract sockets, and it pins node-gyp 7, which dies on Node 24 ("Completion callback
never invoked"); upstream's own flake skips these two extensions for that reason. `--omit=optional`
was tried and also drops esbuild's platform binary, so only `usocket` goes, through a patched
`packageLock` handed to `importNpmLock`. The system and session buses are path sockets, so the
abstract-socket branch is never taken.

**What these four need.** zoxide is pinned by store path in `postPatch`, like `pactl` below.
timer and reminders need `notify-send`, which nothing installed until 16/10/2026: `libnotify` goes
on the profile from `extensions.nix`, because timer's call runs inside a transient unit through
`bash -c`, on the user manager's PATH, where a store path patched into the bundle would not reach.
reminders keeps its state in its own support folder and schedules transient units, so nothing lands
in `~/.config/systemd/user`; its Complete and Snooze buttons work because Quickshell's notification
server declares `actionsSupported`. ssh reads the generated `~/.ssh/config` and runs its
`terminal` preference followed by the host, hence `kitty ssh`.

**ollama-wordsmith runs `qwen3.5:latest` with thinking off.** Upstream's default model,
`translategemma`, is not pulled here. Measured on 16/10/2026 on a short PT→EN sentence:
`qwen3:4b` reasons before answering whatever the request says (22 s, and with `think: false` the
reasoning lands IN the reply), while `qwen3.5` with `think: false` answered with the bare
translation in 6 s. The extension sends no `think` field, so `postPatch` adds `think: false` to
its `/api/chat` body. Target language English; change `targetLanguage` in `default.nix`.

Considered on 16/10/2026 and left out: otp (TOTP secrets in a second store beside Bitwarden),
kde-connect (LocalSend is the phone path here), hypr (the cheatsheet covers keybinds),
process-manager and port-killer (`btop` and `ss`/`kill` in a terminal do it), protondb-search and
it-tools (a browser search away).

**vscode-recents reads `~/.vscode-shared/sharedStorage/state.vscdb`**, where VS Code 1.142 keeps
`history.recentlyOpenedPathsList` (59 entries on 15/10/2026); the old
`~/.config/Code/User/globalStorage/state.vscdb` no longer has the key. It reads the file with
sql.js (WebAssembly, no native build), which skips the `-wal` beside it, so a folder opened a
moment ago can be missing until VS Code checkpoints. It runs `code` from PATH, which the profile
provides. Opening the dotfiles themselves is the `dotfiles-code` script, not this.

Two patches, both `--replace-fail`. **No existence check per entry**: upstream calls `existsSync`
on every local path, and on 16/10/2026 the list never loaded because several entries live under
`~/FAI-workstation`, the rclone mount, while the workstation was unreachable through an
apparently up VPN. A `stat` there sits in D state until rclone gives up (minutes), and a sync call
freezes the extension's event loop with it. Entries now show unchecked, which is what VS Code's own
Open Recent does. **No "Remove from Recents"**: it rewrote `state.vscdb` from an in-memory copy
while VS Code holds the file open in WAL mode, which can drop or corrupt VS Code's own writes.

**pactl is pinned twice, by store path.** The built-in volume commands look it up on PATH once at
startup (`QStandardPaths::findExecutable("pactl")`), and with nothing providing it they toasted
"Failed to set volume" while the journal said `pactl not found, audio control will not work`. The
pulseaudio extension runs it by bare name too. So the package's `postPatch` and the extension's
each swap in `pkgs.pulseaudio`'s `pactl`, used only as a client: PipeWire's pipewire-pulse answers
it (`Server Name: PulseAudio (on PipeWire 1.6.6)`), and nothing enables the PulseAudio daemon.
`--replace-fail` breaks the build if upstream moves either call.

To add one, put its folder name in the list; if its tsconfig extends the repo root or it needs a
native module, see how upstream's `flake.nix` builds it first.

### Repositories

`modules/home/desktop/vicinae/repositories/` is my own extension (15/10/2026), built by the same
`mkExtension` from the folder. One command lists, filtered as I type and grouped by account:

- the GitHub accounts in `githubOwners`, in that order: `v1cferr`, `victor-ferreira-fai-ufscar`
  (the FAI account) and `drakko2002` (my brother's). It merges `/user/repos` (what the token can
  read, the private repos included) with each account's `/users/<login>/repos`, because the GitHub
  extension's own "My Repositories" lists only repos I own or collaborate on, which left out six of
  my brother's.
- the projects I am a member of on FAI's GitLab, through its API with the `fai_gitlab_token`
  (`read_api`, the glance band's), read from `/run/secrets` by path so it never sits in the settings.

On 15/10/2026 that is 66 + 14 + 8 on GitHub (25 private) and 25 on GitLab. Each row shows where it
lives at a glance: the platform's icon on the left (GitHub in the text color, GitLab in orange), a
lock when it is not public, and the owner's avatar on the right (the account, or the GitLab group
or user). A side panel, on by default and toggled with Ctrl+D (remembered), holds the rest: owner,
my access (GitHub's Admin/Write/Read from the token's `permissions`, GitLab's role from the larger
of project and group access), visibility, archived and fork, language, default branch, stars,
forks, topics, last activity and creation date. Enter opens the repo, and the actions copy the SSH
clone URL or the URL, open the owner's page, or refresh (Ctrl+R). The last list is cached, so it
opens at once and refreshes behind; without the FAI VPN the GitLab part keeps its cached entries
and a toast says it could not refresh. GitLab has no language in its project list, so that row is
GitHub only.

Its preferences are overrides in `default.nix` (provider `@v1cferr/repositories`), and its GitHub
token is the same sops render as below. To change the list, edit `githubOwners` there. The
`assets/icon.png` is the Nerd Font repo glyph in the accent color, and the one PNG `.gitignore`
lets through: an untracked file is not in the flake's source, so without the exception the build
had an empty `assets/`. To work on it: `npm install` in a copy of the folder, `npx tsc --noEmit`,
and the lock goes back here. Do not run `vici build` in place, it installs into
`~/.local/share/vicinae/extensions/` beside Home Manager's links.

### Bitwarden

`bitwarden.nix` (16/10/2026). The extension drives `rbw`, an unofficial Bitwarden CLI whose agent
(`rbw-agent`) holds the decrypted keys in memory while unlocked, the price of a vault searchable
from SUPER+SHIFT+P. The official `bw` CLI and the desktop app stay as they were; `sync-secrets`
still uses `bw`.

- **Unlock.** The extension shows "Press Enter to unlock" and runs `rbw unlock`, which opens
  pinentry-qt for the master password. After `lock_timeout` (3600 s) idle the agent forgets the
  keys and the next search asks again.
- **Copy, not paste.** Copies go out with `concealed: true`, and Vicinae drops a concealed
  selection from its history (`clipboard-mime.cpp`), so a password never lands in SUPER+SHIFT+V.
  The Paste actions need `vicinae-input-server`, which is off on purpose, so they do nothing here.
- **The config is a sops render.** rbw needs the account email in `~/.config/rbw/config.json`,
  and the repo is public, so the file is `sops.templates."rbw-config.json"` in
  `modules/nixos/core/secrets.nix` (owner me, 0400: email, `lock_timeout`, pinentry-qt's store
  path), linked into place by `mkOutOfStoreSymlink`. rbw only reads that file; the device id and
  the encrypted local copy of the vault live in `~/.local/share/rbw` and `~/.cache/rbw`.

Setting it up, once:

1. In Bitwarden, a Login item named **Bitwarden Email** with the account email in the password
   field, the same shape as **Caddy ACME Email**.
2. Add `"rbw_email": "Bitwarden Email"` to `secrets/bitwarden-secrets.json` (not before:
   `dead-config` refuses an index entry with no value in `secrets.yaml`).
3. `sync-secrets`, then `rebuild`: the template appears and so does the link.
4. `rbw login` in a terminal (pinentry asks for the master password, and the 2FA code if the
   account has one). If bitwarden.com refuses the login as an unknown client, `rbw register` with
   the account's personal API key (Settings, Security, Keys) and then `rbw login` again.

### The GitHub token

The extension's `personalAccessToken` is a password preference (the Repositories extension's
`githubToken` rides the same file). Vicinae reads the merged config
before its own database for those (`root-item-manager.cpp`), so the token arrives as one more
override file, rendered by sops-nix into `/run/secrets/rendered/vicinae-github.json` (owner me,
0400) and appended to `VICINAE_OVERRIDES`. The store only ever holds sops's placeholder (checked
by evaluating the template on 13/10/2026).

The token is in the vault since 14/10/2026 (classic, the five scopes below). GitHub has no API to
create a personal access token, so `gh` cannot mint one; reusing `gh`'s own OAuth token was
rejected, because it carries `delete_repo` and dies silently on a `gh` re-login. Without the key
the template is not declared and the extension asks for the token in its own form. To set it up
again (or rotate it):

1. Create a classic token at
   `https://github.com/settings/tokens/new?description=Vicinae&scopes=repo,notifications,project,read:org,read:user`
   and save it in Bitwarden as **Vicinae GitHub Token**, in the password field of a Login item.
2. Add `"vicinae_github_token": "Vicinae GitHub Token"` to `secrets/bitwarden-secrets.json`.
3. `sync-secrets`, then `rebuild`. `modules/nixos/core/secrets.nix` declares the template once the
   key exists in both places, and the Vicinae unit restarts with it.

## The browser

The Vicinae add-on (`firefox@vicinae.com`, signed, on AMO) talks to the server through native
messaging. The nixpkgs build writes the host manifest itself at every start, into
`~/.mozilla/native-messaging-hosts/` and, because `~/.zen` exists, into
`~/.zen/native-messaging-hosts/`. The manifests were there after the first start on 13/10/2026,
pointing at the store's `vicinae-browser-link`; they are rewritten at every start, so a version
bump repoints them.

The add-on itself comes from Zen's `ExtensionSettings` policy (`modules/home/apps/zen.nix`), added on
14/10/2026: `normal_installed` from AMO's `latest.xpi`, so it is the signed AMO build (signature
checks unchanged), AMO keeps it current, and it can still be disabled in `about:addons`. Its only
permissions are `tabs` and `nativeMessaging` (AMO API, 1.0.0). It gives tab search, focus and close
from Vicinae's root, and turns a tab into a shortcut. Upstream also suggests granting "Run on sites
with restrictions" by hand in `about:addons`; no policy key covers that per-add-on choice, and tab
listing does not need it. Tabs showed up in Vicinae on 14/10/2026, once the add-on was connected.

Their icons were the generic window glyph at first: the add-on sends no favicon, and the server
(`BrowserTab::icon` in `browser-extension-service.hpp`, 0.29.0) asks the `favicon_service` for the
tab's HOST, which was `none`. It is `google` since 14/10/2026: the host only (never the path or the
query) goes to `google.com/s2/favicons`, once per domain, and the PNG is cached in
`~/.local/share/vicinae/favicon/`. Twenty (the default, a small independent service) was the other
choice; Google covers more domains. A domain it does not know falls back to the window glyph.

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
