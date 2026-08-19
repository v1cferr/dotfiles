# notes

One page per module, holding what used to live in its header block: **why the module is the
way it is**, the measurements behind each number, and what was tried and rejected.

## Why this folder exists

Rule 2 used to allow a header block "as long as it needs to be". Measured on 16/08/2026, that
had grown into **6062 comment lines out of 16634** across the tree, 36%, with one module
(`home/shell/claude-code.nix`) carrying a **123-line header**. A header that long stops being
documentation and becomes a wall you scroll past to reach the code. Worse, none of that
reasoning was reachable from `docs/`: to find out why Caddy has a jail, you had to already know
to open `system/services/caddy.nix`.

So the reasoning moved here instead of being deleted. The module keeps a 2-line header that says
what it is and points at its page. After the sweep the tree is at **1601 comment lines out of
13299**, 12%, and no comment anywhere runs longer than 2 lines.

**Nothing was deleted.** Every measurement, every rejected alternative and every correction that
was in a header is on one of these pages. If you find something here that the code no longer
does, that is rule 16 and the page is the bug.

## How it relates to the rest of docs/

| Folder | Question it answers |
| --- | --- |
| [`../history/`](../history/) | "What happened on that day, and what did I learn?" Chronological, append-only |
| `notes/` (here) | "Why is THIS module like this, right now?" One page per module, kept current |
| [`../guides/`](../guides/) | "What do I type to redo this by hand?" Steps outside Nix's reach |

The history is a diary and keeps its entries even when they go stale, because a diary that gets
edited stops being evidence. These notes are the opposite: they describe the CURRENT state, and
rule 16 applies in full, so a note that stops being true is a bug.

## Conventions

- **Grouped by SUBJECT, not by repo path.** A mirror of the tree was measured and rejected: 16 of
  the 51 pages cross the `system/` and `home/` boundary (arch-legacy, claude-code, monitors, theme,
  restic, vpn, fonts and others) and 19 reference two or more modules. They cross because the
  ARTIFACT crosses, so a mirror would have to split a third of the pages or file them under a
  half-truth. The folder answers "where would I go looking", which is the question a reader
  actually has.
- **The file name mirrors the module**, so `system/services/caddy.nix` becomes
  `network/caddy.md`. When a page covers several modules it takes the name of the SUBJECT
  (`desktop-plumbing.md`, `apps-and-mime.md`).
- **A page is created only when there is something to say.** A module whose header compresses to
  2 lines with nothing lost does not get a page.
- **The module points here, never the other way around.** The pointer lives in the 2-line header,
  and [`repo/link-checker.md`](repo/link-checker.md) is what keeps those pointers honest: a broken
  one fails `nix flake check`.

## The pages

### boot-and-storage

| Page | What you would come here asking |
| --- | --- |
| [boot](boot-and-storage/boot.md) | why GRUB and not systemd-boot, and what Secure Boot here does NOT protect |
| [disko](boot-and-storage/disko.md) | the subvolume layout, and why the swapfile belongs to the host |
| [btrfs](boot-and-storage/btrfs.md) | the scrub, the alarm, the reclaim, and why fstrim is off |
| [btrbk](boot-and-storage/btrbk.md) | the local snapshots, which are NOT a backup |
| [restic](boot-and-storage/restic.md) | the real backup, plus `~/Drive` and the CS2 saves |
| [arch-legacy](boot-and-storage/arch-legacy.md) | the old Arch archive, permanently mounted, and `--no-lock` |
| [disk-hygiene](boot-and-storage/disk-hygiene.md) | the space alarm that names the biggest consumers |
| [shutdown](boot-and-storage/shutdown.md) | why the machine takes that long to go down |

### hardware

| Page | What you would come here asking |
| --- | --- |
| [gpu](hardware/gpu.md) | the Arc B580 on `xe`, and why the driver stack must NOT go unstable |
| [monitors](hardware/monitors.md) | the connector SSOT, and why it lives on the system side |
| [fonts](hardware/fonts.md) | the UI font SSOT, and the fallback coverage |
| [mouse](hardware/mouse.md) | the MX Master, the boot race, and the gestures |
| [oom](hardware/oom.md) | earlyoom, and the three traps in its regex |

### network

| Page | What you would come here asking |
| --- | --- |
| [network](network/network.md) | the firewall by SOURCE, the DDNS that moved to the router, fail2ban, the FAI gateway |
| [vpn](network/vpn.md) | FAI (nxBender) and UFSCar (openconnect), always split-tunnel |
| [ssh](network/ssh.md) | the exposed SSH, the hosts, and reaching the FAI workstation |
| [sunshine](network/sunshine.md) | remote access, the black screen, and why dpms is forbidden |
| [caddy](network/caddy.md) | the reverse proxy, the auto-gate, `client_ip` vs `remote_ip` |
| [fai-workstation](network/fai-workstation.md) | the host SSOT, Wake-on-LAN, and the rclone mount |

### desktop

| Page | What you would come here asking |
| --- | --- |
| [desktop](desktop/desktop.md) | Hyprland, the autologin trade, the portals, the keyring |
| [hypr](desktop/hypr.md) | the Lua config, the helper scripts, the remote-access safety net |
| [keybinds](desktop/keybinds.md) | every bind, and why the cheatsheet is generated from them |
| [quickshell](desktop/quickshell.md) | the shell in QML, and the 758 MiB XEmbed bridge |
| [bar](desktop/bar.md) | the bar and its popovers, the VPN probe, the holiday table |
| [lockscreen](desktop/lockscreen.md) | hyprlock and hypridle, and the three hardware lessons |
| [theme](desktop/theme.md) | dark mode, Kvantum, the Win11 icons, the palette SSOT |
| [autostart](desktop/autostart.md) | what opens at login, and Spotify's 4145 restarts |
| [hyprsunset](desktop/hyprsunset.md) | the blue light curve, and why 13 profiles |
| [desktop-plumbing](desktop/desktop-plumbing.md) | the polkit agent, XDG associations, the wallpaper, rofi |

### apps

| Page | What you would come here asking |
| --- | --- |
| [dolphin](apps/dolphin.md) | the ViewMode enum trap, and the Windows Explorer parity |
| [dropbox](apps/dropbox.md) | the tray icon's cost, and 10 days of syncing nothing |
| [vscode](apps/vscode.md) | a versioned mirror and not an immutable source |
| [claude-code](apps/claude-code.md) | two accounts, one archive, and the rules every project inherits |
| [azure-mcp](apps/azure-mcp.md) | the Azure MCP server, FAI only |
| [flameshot](apps/flameshot.md) | the v14 keyboard flow, and the duplicated bar |
| [curseforge](apps/curseforge.md) | the repackaged AppImage, and why the schemes are declared |
| [curseforge-fix-perms](apps/curseforge-fix-perms.md) | the `+x` the app loses, and why ELF magic and not names |
| [mega](apps/mega.md) | megatools, the quota, and why the loop waits |
| [apps-and-mime](apps/apps-and-mime.md) | media, office, MangoHud, OpenAL, and the CANONICAL mimetype |

### services

| Page | What you would come here asking |
| --- | --- |
| [service-toggles](services/service-toggles.md) | the optional-service list, and why it is centralized |
| [jellyfin](services/jellyfin.md) | the media library, the UMask override, DLNA on the TV |
| [ollama](services/ollama.md) | local models on the Arc through Vulkan |
| [duo](services/duo.md) | the compose stack declared in Nix, and the three Docker traps |
| [grad-radar](services/grad-radar.md) | the stack at boot, and the monitor chain's order |
| [docker-prune](services/docker-prune.md) | the 11 GB with no ceiling, and the two options that destroy data |

### repo

| Page | What you would come here asking |
| --- | --- |
| [flake](repo/flake.md) | the inputs, the overlays, and the quality gate |
| [core](repo/core.md) | Nix settings, the GC, locale, and why each ceiling is that number |
| [packages](repo/packages.md) | what is installed and why, per package |
| [shell](repo/shell.md) | zsh, the aliases, and the `NH_FLAKE` trap |
| [secrets](repo/secrets.md) | sops-nix, Bitwarden, and the two recipients |
| [version-bumps](repo/version-bumps.md) | the three-layer version strategy, and the bump scripts |
| [link-checker](repo/link-checker.md) | what keeps these pointers from rotting |
| [dead-config](repo/dead-config.md) | what is declared and never used, and the seven checks |
| [router-ssot](repo/router-ssot.md) | the values the router repeats, and who guards them |
