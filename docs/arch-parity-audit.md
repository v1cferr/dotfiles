# Arch parity audit

The measurement that says whether the migration is DONE. Measured on 08/09/2026, before
promoting `nixos` to the default branch and retiring the Arch refs.

This is not the same page as [arch-linux.md](arch-linux.md), and the difference matters: that
one is the pointer to the restic ARCHIVE (the 44.6 GiB snapshot of the old machine); this one is
the diff of the CONFIGURATION that still lives in this repo's own Arch branches. The archive
answers "where is my old data"; this answers "what did I never port".

It is a SNAPSHOT and not a note kept current (rule 16 draws that line): a re-measure is one
sweep of the same greps, and the number that ages is the count, not the method. Whatever gets
ported closes here and moves to [open-items.md](open-items.md) or to
[history/](history/), the same as any other work.

## What was compared

Every ref in the repo, because "check all the branches" was the ask and three of the six carry
no configuration of their own:

| Ref | Files | What it holds |
| --- | --- | --- |
| `main` | 659 | The FULLEST Arch snapshot: `arch` plus 2 commits (the netextender NAT gateway and one VS Code tweak) |
| `arch` | 656 | The same tree, 2 commits behind `main`. Nothing exclusive |
| `nixos` | 296 | Today's config. An ORPHAN history: no merge base with `main` or `arch` |
| `backup-ptbr-msgs` | - | Branched off `nixos`. Only pt-BR commit messages, no config of its own |
| `salvaguarda-voz` | - | Branched off `nixos`. Same thing, the voice safeguard of rule 17 |
| `fix/jellyfin-wait-ipv4` | - | Already merged into `nixos` (0 commits ahead) |
| tag `archive/pre-nix-2026-07-16` | - | It preserves the 493 pre-Nix COMMITS, but its TREE is the post-reset clean slate |

So the real comparison is **`main` against `nixos`**, and the tag is a history anchor rather
than a source of files. The wallpapers dominate `main`'s count (369 of the 659), which is why
the file totals say less than the area totals below.

## The verdict

53 configuration areas on the Arch side, and the split is what a finished migration looks like
with a tail:

| Verdict | Areas | Meaning |
| --- | --- | --- |
| Migrated | 25 | Declared on NixOS, same job, usually a superset |
| Replaced | 9 | A different tool doing the same job, on purpose |
| Dropped on purpose | 2 | Decided against, with the reasoning already written down |
| Arch-only | 1 | Meaningless outside pacman |
| Partial | 8 | The app came across, some of its config did not |
| Missing | 8 | Nothing on this side at all |

The 16 areas in the last two rows are the whole of what is left, and none of them holds the
machine back: the desktop, the network, the boot, the backup, the secrets and the remote access
are all on this side. What is left is a self-hosted stack, some comfort in the shell, and a
handful of app configs.

## Area by area

Arch paths are written `main:<path>` on purpose, the git-rev form, so the docs link checker
does not read them as paths that should exist on this branch.

### Migrated

| Arch area | Where it lives now |
| --- | --- |
| `main:hypr/` (37 files) | [`home/desktop/hypr.nix`](../home/desktop/hypr.nix) plus 7 Lua files. Two deltas, below |
| `main:quickshell/` (17) | [`home/desktop/quickshell.nix`](../home/desktop/quickshell.nix) plus 25 QML files, a superset |
| `main:vscode/` (8) | [`home/apps/vscode.nix`](../home/apps/vscode.nix): settings, keybindings, MCP and the extension mirror |
| `main:netextender/` (12) | [`system/net/vpn.nix`](../system/net/vpn.nix) (nxBender) plus [`system/net/fai-gateway.nix`](../system/net/fai-gateway.nix); the WoL scripts became `wake-workstation` |
| `main:networkmanager/` | The UFSCar profile became openconnect/GlobalProtect in the same `vpn.nix` |
| `main:fail2ban/` (5) | [`system/net/network.nix`](../system/net/network.nix) plus the generated jail in [`system/services/caddy.nix`](../system/services/caddy.nix) |
| `main:ssh/` (4) | `network.nix` (port 2222, now with TOTP) plus [`home/shell/ssh.nix`](../home/shell/ssh.nix) |
| `main:caddy/` (3) | `caddy.nix`, with the vhosts GENERATED from `my.ingress`. The subdomain SET is smaller, see Partial |
| `main:wireguard/` | [`router/uci/`](../router/uci/network.conf), because the tunnel moved to the router |
| `main:system/` (14) | [`system/core/core.nix`](../system/core/core.nix) (locale, timezone, `br-abnt2`), `hostName` per host, [`system/core/boot.nix`](../system/core/boot.nix) |
| `main:swap/` | `zramSwap.enable` in [`system/hardware/hardware.nix`](../system/hardware/hardware.nix) |
| `main:fontconfig/` | [`system/hardware/fonts.nix`](../system/hardware/fonts.nix), a superset: CJK plus corefonts plus vista-fonts |
| `main:gtk-3.0/`, `main:gtk-4.0/` | [`home/desktop/theme.nix`](../home/desktop/theme.nix) plus [`home/desktop/palette.nix`](../home/desktop/palette.nix) |
| `main:rofi/` | [`home/desktop/launcher.nix`](../home/desktop/launcher.nix) plus [`home/desktop/clipboard.nix`](../home/desktop/clipboard.nix), themed from the palette |
| `main:kitty/` | [`home/shell/kitty.nix`](../home/shell/kitty.nix). Small deltas, below |
| `main:starship/` | [`home/shell/starship.nix`](../home/shell/starship.nix) |
| `main:git/` | [`home/shell/git.nix`](../home/shell/git.nix) |
| `main:fastfetch/` | [`home/shell/fastfetch.nix`](../home/shell/fastfetch.nix) |
| `main:flameshot/` | [`home/apps/flameshot.nix`](../home/apps/flameshot.nix), with the `sc1`/`sc2` aliases by monitor NAME |
| `main:mpv/` | `programs.mpv` in [`home/apps/media.nix`](../home/apps/media.nix) |
| `main:uv/` | The package in [`system/packages.nix`](../system/packages.nix); the receipt is state (rule 6) |
| `main:autostart/` | [`home/apps/dropbox.nix`](../home/apps/dropbox.nix) plus [`home/desktop/autostart.nix`](../home/desktop/autostart.nix), one unit per app |
| `main:claude/` | `claude-desktop-fhs` in [`home/packages.nix`](../home/packages.nix) |
| `main:.claude/` | [`.claude/settings.json`](../.claude/settings.json), plus the managed layer of [`system/services/claude-code.nix`](../system/services/claude-code.nix) |
| The root `.md` files | The whole of [docs/](README.md). `ANOTACOES.md` was 1949 lines and became this tree |

### Replaced

Same job, a different tool, and each one has its reasoning already recorded:

| Arch area | What does the job now | Why |
| --- | --- | --- |
| `main:waybar/` (23) | The Quickshell bar | The port happened while still on Arch; the bar is QML now |
| `main:swaync/` | Quickshell's notification service | One daemon fewer, and it is already the tray owner |
| `main:xsettingsd/` | `gtk` plus `dconf` in `theme.nix` | The idiomatic home-manager path; no X11 daemon |
| `main:greetd/` (7) | LightDM plus autologin in [`system/desktop/desktop.nix`](../system/desktop/desktop.nix) | Sunshine captures a LIVE session, so the machine has to log itself in |
| `main:kwallet/` | gnome-keyring in the same `desktop.nix` | It is the `org.freedesktop.secrets` provider VS Code asks for |
| `main:openrazer/` | hidraw plus `razer-dpi` in [`system/hardware/razer.nix`](../system/hardware/razer.nix) | openrazer does not build on kernel 7.1 or newer |
| `main:cloudflare-ddns/` (4) | `ddns-scripts` on the router, [`router/uci/ddns.conf`](../router/uci/ddns.conf) | The anchor stopped depending on this machine being awake |
| `main:docker/` | [`system/services/docker.nix`](../system/services/docker.nix), the prune policy | The only content was the nvidia runtime, and the GPU is an Arc now |
| `main:bash/` | zsh as the login shell | `.bashrc` was already vestigial |

### Dropped on purpose

| Arch area | Decision |
| --- | --- |
| `main:wallpapers/` (369 files) | `pkgs.nixos-artwork` instead, so no binary lives in git. Recorded in the [july history](history/2026/07-july.md). The images went; the ROTATION went with them, which is a delta and not a decision, see below |
| `main:cloudflare/` (the tunnel) | `expose = "public"` works without it. Written down in the [august history](history/2026/08-august.md): "there is no need for cloudflared" |

`main:pacseek/` is the one area that has no NixOS meaning at all.

## The eight partial areas

### `main:homelab/` plus the Caddy subdomain set

This is the biggest gap by far, and the only one that is a project rather than a chore. Arch
served **14 subdomains**; this branch declares **5**, and one of those (`pos`, GradRadar) is new
and never existed over there.

| Subdomain | Port | On NixOS |
| --- | --- | --- |
| `jellyfin` | 8096 | Yes, and NATIVE now instead of a container |
| `torrent` | 8080 | Yes, native ([`system/services/qbittorrent.nix`](../system/services/qbittorrent.nix)) |
| `ai` | 11434 | Yes, `expose = "lan"` ([`system/services/ollama.nix`](../system/services/ollama.nix)) |
| `duo` | 3010 | Yes ([`system/services/duo.nix`](../system/services/duo.nix)) |
| `chat` | 3000 | No. open-webui |
| `jellyseerr` | 5055 | No |
| `prowlarr` | 9696 | No |
| `radarr` | 7878 | No |
| `sonarr` | 8989 | No |
| `bazarr` | 6767 | No |
| `spendflow` | 3001 | No |
| `ap` | 3005 | No. ufscar-housing-radar (V1C-68) |
| `dash` | 3003 | No. Homepage, plus its docker-socket-proxy |
| `files` | 3004 | No. FileBrowser, and its fail2ban jail went with it |

Two containers had no subdomain and are also absent: `flaresolverr` (the \*arr stack's captcha
solver) and the RustDesk server (`hbbs`/`hbbr`).

The port table in [notes/network/caddy.md](notes/network/caddy.md) already RESERVES every one of
those numbers, and [notes/services/jellyfin.md](notes/services/jellyfin.md) says the \*arr apps
"come later, one module at a time", so this is a queue and not an oversight. The one thing to
know before working it: the DNS records for `bazarr`, `prowlarr`, `radarr`, `sonarr`,
`jellyseerr`, `spendflow`, `chat`, `dash` and `files` were REMOVED from the zone and from the
router's dnsmasq during the august cleanup. The wildcard covers them again the moment a vhost
exists, but a stale mental model of "the DNS is already there" is not true anymore.

### `main:zsh/`

The structure came across whole (history options, autosuggestions, syntax highlighting, the
zoxide-goes-last trick, the eza and screenshot aliases, and the Claude accounts, which are
better here). What did not:

- **atuin.** The Arch `.zshrc` bound Ctrl+R to `atuin-search`; here Ctrl+R is fzf's. Atuin is a
  searchable, statistics-keeping, syncable history, and it appears NOWHERE on this branch. It is
  its own Missing entry below.
- **The keybindings.** `bindkey` does not exist in this branch: Home, End, Delete, Ctrl+arrow
  word jumps, the double-Esc that prefixes `sudo`, and Alt+R for the fzf history widget. The
  word jumps and the sudo trick are certainly gone; whether Home/End still work depends on what
  terminfo gives zsh under kitty, so that one is worth TESTING rather than assuming.
- **`fastfetch` at shell startup.** The module is configured and nothing ever calls it, so the
  summary that used to greet every terminal does not.
- **`EDITOR`.** Unset anywhere on this branch. Arch pinned `nano`, which is also not installed
  here; `vim` is.
- **The YouTube and mpv aliases**: `yttui`, `ytmix`, `ytvideo`, `ytaudio`, `ytwatch`, with the
  playlist URL and the format strings. `yt-dlp` and `mpv` are both declared, so this is five
  aliases and one URL.
- **`fhome` and `froot`**, the fd plus fzf jump-to-any-file pair.
- **Small ones**: `grep --color=auto`, `nrd`, and `ssh` forcing `TERM=xterm-256color`.

Deliberately gone, and correctly so: the pacman `update`/`clean` aliases, the `arch-update`
wrapper with its AUR supply-chain gate, `stow-sync`, and the `.zprofile` that started Hyprland
through uwsm on TTY1. The toolchain `PATH` exports (dotnet, pnpm, conda, dart, opencode) are
gone by policy, since toolchains live in a devShell reached by direnv now.

### `main:bin/`

| Script | Status |
| --- | --- |
| `vpn`, `vpn-off` | The `vpn` CLI in `system/net/vpn.nix`, and it needs no password (polkit) |
| `wake-fai` | `wake-workstation` in [`home/net/fai-workstation.nix`](../home/net/fai-workstation.nix), with three WoL paths instead of one |
| `dark-mode`, `tokyo-night` | Obsolete by construction: the theme is a Nix palette applied at build time (rule 9) |
| `hypr-quick` | Missing. Mostly subsumed by the binds, EXCEPT its wallpaper actions |
| `zen-sync` | Missing, and it is the delivery half of the Zen customization below |

### `main:hypr/`, the two deltas

Everything else in Hyprland is at parity or better: input is a line-for-line port, the window
rules and workspace rules match, the appearance block matches (and gained the `scrolling`
layout), the keybinds are a superset with a generated cheatsheet, and 16 of the 18 loose scripts
became either a `writeShellApplication` or a systemd timer. The two that did not:

- **The wallpaper rotation.** `auto_wallpaper.sh` and `change_wallpapers.sh` implemented a
  smart random walk with a 20-entry history, weights for never-used images and validation before
  use, on SUPER+I, SUPER+SHIFT+I and SUPER+CTRL+I. Here `hyprpaper` serves two fixed images and
  SUPER+I is the scrolling layout's `consume`. Dropping the 369 images was a decision; dropping
  the FEATURE was not written down as one.
- **The 3-minute idle dim.** Arch had a listener that zeroed the gamma at 180s, before the lock
  at 300s, through `idle-dim.sh`. This branch has ONLY the 300s lock listener.
  [`home/desktop/hyprsunset.nix`](../home/desktop/hyprsunset.nix) dims by time of day, which
  covers the evening but not "I walked away at noon".

One more, cosmetic: the lockscreen's notification COUNT label (`lockscreen_notifs.sh`, reading
`qs ipc call notif count`) has no counterpart in
[`home/desktop/lockscreen.nix`](../home/desktop/lockscreen.nix). The clock, date, user, quote
and weather labels are all there, and the quotes got better (a ZenQuotes plus DeepL timer
replaced the vendored TSV).

### `main:kitty/`

Parity on everything that matters, with a rewrite rather than a port, so a few settings simply
were not carried: `cursor_shape beam`, `hide_window_decorations`, `wheel_scroll_multiplier 5.0`,
the `repaint_delay`/`input_delay` tuning, `disable_ligatures never`, and the F8/F9/F10 plus
Ctrl+Alt+A/C maps. The font went 11 to 12, the opacity 0.92 to 0.95, the scrollback 15000 to
10000 and the padding 12 to 8, which read as choices, not losses.

### `main:btop/`, `main:vlc/`, `main:gh/`

The same shape three times: the PACKAGE is declared and the CONFIG is not. `btop.conf` (the
theme and the layout), `vlcrc` and `gh/config.yml`. All three are small and all three are the
kind of file the app rewrites itself, so rule 14 decides the form: an activation script or an
immutability marker, not a managed file.

### `main:zen-browser/`

The browser is declared and is the default (`$BROWSER`, and the mime associations in
[`home/desktop/xdg.nix`](../home/desktop/xdg.nix)). Its CUSTOMIZATION is not: `userChrome.css`
(618 lines) and `user.js` (18 prefs). This is the pair `zen-sync` used to deliver.

### `main:scripts/`

47 files, and most of them are Arch by nature: the pacman and AUR package sync with its systemd
timer, the AUR supply-chain checker, `stow-sync.sh`, the rEFInd menu cleanup, and one `deploy.sh`
per service, which is what "no declarative layer" costs. What had real content came across:
the secrets backup became [`scripts/sync-secrets.sh`](../scripts/sync-secrets.sh) plus sops-nix,
the wireguard and WoL router scripts became `router/uci/`, and the VPN scripts became the `vpn`
CLI. Nothing here needs porting; it needs deleting along with the branch.

## The eight missing areas

Ordered by what I would actually miss, not alphabetically:

1. **atuin** (`main:atuin/`). The shell history with search, stats and sync. Nothing on this
   branch. It has a home-manager module (`programs.atuin`), and the trap is already documented
   next door: whatever initializes last fights zoxide's doctor, so the `mkOrder` in
   [`home/shell/cli.nix`](../home/shell/cli.nix) is the place to read first.
2. **easyeffects** (`main:easyeffects/`, 4 files). CORRECTED on 08/09/2026, because the first
   pass of this page called these "presets" and they are not: `equalizerrc` and `compressorrc` are
   EMPTY, `bassEnhancerrc` holds one line (`floorActive=true`), and `easyeffectsrc` only records
   which three plugins were in the chain. So the chain was enabled and never tuned. Worse for
   porting, `easyeffectsrc` pins input and output to
   `alsa_output.usb-Jieli_Technology_HECATE_G1500_MAX-00`, a headset that no longer appears in
   `wpctl status`. There is no tuning to carry over, only the decision to build a chain again.
3. **polychromatic** (`main:polychromatic/`, 6 files). The Razer RGB GUI, and it is absent for
   the same reason openrazer is: no daemon. This connects to the OpenRGB item already open in
   [open-items.md](open-items.md), which is about the Arc B580's RGB rather than the mouse's, but
   it is the same missing layer.
4. **Neovim** (`main:nvim/`, 13 files). CORRECTED on 08/09/2026, and this one reverses the
   verdict: the first pass called it "a full LazyVim setup", and it is STOCK BOILERPLATE.
   `options.lua`, `keymaps.lua` and `autocmds.lua` have ZERO active lines, all three being
   comment-only stubs, and `lua/plugins/example.lua` opens with `if true then return {} end`,
   LazyVim's own early return, so its 134 remaining lines never execute. What is in there is the
   distributed example, gruvbox and a lualine that returns an emoji included. There is nothing
   personal to port, and the `lazy-lock.json` pins plugins for a config that does not exist.
5. **spicetify** (`main:spicetify/`). Spotify theming. Spotify is declared (with `--no-zygote`
   baked into the package); the theme is not. There is a community flake for it, and it patches
   the app, so it argues with rule 14 and deserves reading before doing.
6. **opencode** (`main:opencode/`). One config file for an agent CLI that is not declared here at
   all. Claude Code, codex and agy are; this one has to be a decision, since three is already a
   lot of them.
7. **lazydocker** (`main:lazydocker/`). A docker TUI. Neither package nor config.
8. **nano** (`main:nano/`). The `.nanorc`, and nano itself is not installed. If `EDITOR` gets set
   (see zsh above), this is the same decision seen twice.

## Before the cutover

The branch promotion is not blocked by anything above; it is blocked by one thing that is not in
this repo. Recording the order so it does not get improvised:

1. **The default branch never gets swapped to force anything.** That is the lesson of the
   contributions incident: `main` and `nixos` are ORPHAN histories, so pointing the default at the
   wrong one zeroed the graph. The promotion has to be the deliberate, final one.
2. **Decide the 16 tail areas first.** Each one is either a port or a struck-through decision.
   What gets ported closes here; what gets dropped gets a line saying why, because "it is in the
   old branch" stops being an answer the day the old branch is gone.
3. **The refs to retire**, once the tail is decided: the `arch` and `main` branches, and the
   `nix-flake-skeleton` tag, which points at a commit whose whole content is the pivot doc.
4. **The tag to KEEP**, and this is the one that must not be swept up with the rest:
   `archive/pre-nix-2026-07-16` is the only ref holding the 493 pre-Nix commits. Deleting it
   loses them, since the branches it hangs off are the ones being deleted. If the branches go,
   that tag is the last anchor, and a tag is enough to keep the objects alive.
5. **The restic archive is a separate question** and it is already answered in
   [arch-linux.md](arch-linux.md): the offsite copy is the only copy, it passed
   `check --read-data`, and it is what the `/mnt/arch-antigo` mount reads. Retiring the git refs
   does not touch it.
