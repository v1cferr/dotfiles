# dotfiles: my NixOS + home-manager

A **declarative**, reproducible system: NixOS (the base) and home-manager (my
dotfiles) in a single flake. One `rebuild` applies system **and** user at once.

- **Base:** stable nixpkgs `nixos-26.05` plus an `unstable.*` overlay on demand, per package.
- **Active host:** `nixos-kingston`, an NVMe KC3000 on btrfs with subvolumes (groundwork for impermanence).
- **Boot:** UEFI/**GRUB** with the minegrub theme, in **dualboot with Windows 11** (SanDisk SSD),
  **Secure Boot** enabled on both, using own keys via `sbctl`.
- **Machine:** Intel i5-11400 (microcode) · Intel Arc B580 (open `xe` driver + Mesa, no CUDA).
- **Desktop:** Hyprland (Wayland) behind the LightDM greeter · PipeWire · ABNT2 keyboard.

## Day-to-day use

Aliases defined in [`home/shell/zsh.nix`](home/shell/zsh.nix):

```bash
rebuild   # nh os switch <flake> && hyprctl reload
update    # vscode-bump + curseforge-bump + nix flake update + vscode-extensions-dump
upgrade   # update && rebuild, the equivalent of `apt update && apt full-upgrade`
gc        # sudo nix-collect-garbage -d, drops old generations
```

`update` is the maintenance ritual, and it does more than bump `flake.lock`: it
recomputes the pinned version and hash of the vendored binaries (VS Code,
CurseForge) and refreshes the VS Code extension mirror. It runs as my user
rather than root, because that is who holds the SSH key for the private inputs.

With no `#host`, `nixos-rebuild` matches the current `hostname` against
`nixosConfigurations`. For a specific host: `sudo nixos-rebuild switch --flake .#<host>`.

## Layout

Organized **by category**: every subject is a subfolder with its own
`default.nix` importing that category's modules. Adding a module is 1 line in
the category's `default.nix`, and the top level never changes.

```text
flake.nix                inputs (nixpkgs, home-manager, sops, disko, zen-browser...) + overlay + hosts
flake.lock               pinned input versions

system/                  SYSTEM, shared by every host (machine-agnostic)
  default.nix            imports the categories below + packages.nix
  core/                  Nix/flakes, boot, users, secrets, locale
  hardware/              CPU/microcode, GPU (Arc B580), audio (PipeWire), fonts
  net/                   NetworkManager, exposed SSH, fail2ban, DDNS, VPNs
  desktop/               LightDM, Hyprland, xkb, portal, gnome-keyring
  services/              restic, btrbk, Caddy, Jellyfin/qBittorrent, Sunshine, Ollama/duo
  packages.nix           CENTRAL LIST of SYSTEM packages (rescue/base + diagnostics)

home/                    USER (home-manager): dotfiles + user apps
  default.nix            imports packages.nix + the categories + stateVersion
  packages.nix           CENTRAL LIST of user apps/CLIs (the ones with no config of their own)
  shell/                 zsh, starship, cli, kitty, git, ssh, claude-code, ntfy
  desktop/               hypr (+helpers), quickshell (bar), hyprsunset, lockscreen, theme, palette, xdg
  apps/                  apps WITH config of their own: dropbox, media, dolphin, flameshot,
                         vscode, mangohud, office, openal, curseforge
  services/              drive-mount, fai-workstation-mount, arch-legacy-mount,
                         cs2-saves-backup, claude-discord-rpc, disk-hygiene

pkgs/                    own derivations (outside nixpkgs), exposed in `packages.x86_64-linux`
                         so that `nix build .#nxbender` works. Vendored binaries and helper
                         scripts live here: nxbender, azure-mcp, curseforge (+bump, +fix-java),
                         vscode-bump, claude-code-discord-status
hosts/                   per-machine specifics (hostname, disks, monitors, stateVersion)
  nixos-kingston/        <- the ONLY host (NVMe KC3000, btrfs + subvolumes)
    default.nix          hostname, kernel, extra mounts, my.monitors, stateVersion
    disko.nix            declarative disk layout (btrfs + subvolumes)
    services.nix         PANEL: which optional services THIS machine turns on (my.services.*)
secrets/                 secrets.yaml (sops) + bitwarden-secrets.json
scripts/                 bash/python read by `writeShellApplication` (shellcheck runs at build time):
                         sync-secrets, router-sync, router-moonlight-forward, owfetch
router/                  mirror of the OpenWrt UCI config (router-sync): visible, not declarable
docs/                    what is NOT declarable, plus the repo's diary (see docs/README.md)
  rules.md              the 17 rules. The NUMBERING is API: 169 comments cite "regra N"
  open-items.md          what is still open
  history/<year>/<month>  what was done and WHY (including what was tried and REJECTED)
  ideas.md              considered, not yet decided
  arch-legacy.md         a closed chapter + how to open the old Arch archive
  guides/                 step by step for what Nix cannot reach (BIOS, Secure Boot, router, Windows)
  tests/                reusable test protocols
```

`README.md` is the only doc at the root. Everything else lives in `docs/`.

> **Note on language.** Rule 17 makes en-US the language of this repo, and the
> migration is incremental: whatever gets touched is left translated. The
> filenames under `docs/` above are still the pt-BR ones because they have not
> been renamed yet, and this listing describes the repo as it is today, not as
> it will be.

## Where does a package go?

Two mirrored central lists: [`system/packages.nix`](system/packages.nix) and
[`home/packages.nix`](home/packages.nix). The per-package decision:

1. **The default is `home/`.** A day-to-day app/CLI with no config of its own is
   1 line in [`home/packages.nix`](home/packages.nix), then `rebuild`.
2. An app **with** declarative config (dotfiles / `programs.*`) gets its own
   module under `home/`, so package and config travel together. For example
   `kitty`, `dolphin`, `flameshot`.
3. It only goes to **`system/`** if it needs **root/rescue** (say `git`/`vim` in
   a root shell), is a **driver/service**, or a **system service uses** it.

Rule of thumb: *when in doubt, `home/`; it only moves up to `system/` if root or
a service needs it.*

`pkgs.foo` is the stable base; `pkgs.unstable.foo` is the unstable channel, per
package, through the overlay.

## Repo conventions

The full set lives in [`docs/rules.md`](docs/rules.md). The ones you need to
read this tree:

Deliberately unnumbered, because in `docs/rules.md` the numbering is API and a
competing list here would be read as rule numbers.

- **`system/` vs `home/` separation** (see "Where does a package go?").
  System-level under `system/`; the app **and** its user config under `home/`.
  Since home-manager enters as a NixOS module (`useGlobalPkgs` +
  `useUserPackages`), one `rebuild` applies both.
- **Organization by category**: each subject in a subfolder with a `default.nix`.
- **Nix = app + config; state = restic.** Saves, Wine prefixes, app
  tokens/sessions are **not** declared. They go to the backup.
- **One summary comment line per config** in `.nix`/`.lua`/`.conf`, plus a
  header block per module saying what it is, WHY it was chosen and the known
  traps. The line keeps it readable; the block is what gives hours back when the
  problem returns six months later.
- **Validate before applying**: `nixos-rebuild build` / `nix eval` clean, and
  atomic commits per feature/task before the switch.
- **An option is DECLARED in `system/` and DEFINED in `hosts/`.** `my.*` is the
  repo's interface (`system/services/toggles.nix`,
  `system/desktop/monitors.nix`); the value is a per-machine answer and lives in
  `hosts/<host>/`. Hardware options deliberately ship without a `default`, so a
  new host that forgets one fails at eval instead of inheriting a lie.
- **Everything is written in en-US**, file names included, and never with a
  `Co-Authored-By:` trailer.

## Secrets (sops-nix)

Secrets stay encrypted in [`secrets/secrets.yaml`](secrets/secrets.yaml),
versioned in git and unreadable without the key. They are decrypted at runtime
into `/run/secrets*`. The private **age** key lives at
`/var/lib/sops-nix/key.txt`, **outside git**, and is the one thing to carry into
a reinstall (it comes out of the Bitwarden master password). The groundwork is
in [`system/core/secrets.nix`](system/core/secrets.nix).

```bash
nix shell nixpkgs#sops -c sops secrets/secrets.yaml   # edit secrets
```

⚠️ Editing a secret requires a `rebuild`, otherwise `/run/secrets` is not
refreshed.

What it holds today: my password hash, the Cloudflare DDNS token and (through
Bitwarden) the restic repository password.

## Backup and remote access

- **restic** ([`system/services/restic.nix`](system/services/restic.nix)):
  encrypted, offsite backup of `~` (Zen, `.claude`, VS Code, documents) to
  **Google Drive**. To browse it: `sudo restic-home-gdrive mount /mnt/backup`,
  which gives one folder per snapshot.
- **SSH** on port `2222` (root off, `fail2ban` on) plus **Cloudflare DDNS**
  keeping `ssh.v1cferr.dev` pointed at the current public IP, so the machine is
  reachable from anywhere without a VPN.

## Reinstalling from scratch / migrating disks

The SanDisk to Kingston cutover runbook was **deleted** once the migration
happened (2026-08-01), because a runbook that has been executed only lies the
next time around. It lives in history, next to the earlier guides:

```bash
git log --oneline --all --diff-filter=D -- MIGRACAO-KINGSTON.md INSTALACAO-WINDOWS.md
git show <commit>^:<file>
```

The summary that does **not** age, for the next install from scratch:

- `disko` does the formatting, declaratively and always by `/dev/disk/by-id/`,
  never by `sdX`. Those letters shuffle between boots, and they already changed
  twice on this machine.
- The **age key** goes in **before** `nixos-install`. Without it sops cannot
  decrypt `hashedPasswordFile` and my account is created with no password.
  Source: Bitwarden.
- `~` comes over **disk to disk**, never from the backup. restic is an archive,
  not an input.
- Whatever is not declared (`/var/lib`, SSH host keys, NetworkManager profiles)
  crosses by hand, and that is exactly the list impermanence will force into
  declaration.
