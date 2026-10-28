# Impermanence: the persistence list, written before it is switched on

`modules/home/persistence.nix`. NOT active: nothing is wiped today.

## Where this stands

The layout is ready since the install (`@persist` exists and is empty, see [disko](disko.md)), and
the plan in `docs/open-items.md` is unchanged: the root goes ephemeral first, the home after. What
this module adds is the HOME's list, written and checked now, so the day it is switched on is a
wiring change and not a guessing session. It only turns on when I say so.

## The model: folders whole, app state by name

The first idea was a file-by-file triage of the home (an inventory of 359 entries and 459.5 GiB on
28/10/2026). It was dropped the same day: deciding every file is work that never ends, and it is
the wrong unit.

- **The user folders persist WHOLE**: the XDG ones (`Desktop`, `Documents`, `Downloads`, `Music`,
  `Pictures`, `Videos`, declared with `xdg.userDirs` in `modules/home/desktop/xdg.nix`) plus
  `Projects`, `Games`, `Archive`, `CS2-Saves-Backup` and the Dropbox data. Keeping them tidy is a
  habit, and what matters goes to Dropbox and the Obsidian vault in it.
- **Hidden state is listed BY APP**: about a hundred entries (keys, game prefixes, browser
  profiles, AI tool sessions, app logins), each with a one-line reason in the module.
- **Everything else is wiped at boot**: caches, leftovers of removed apps, loose files at the root
  of the home. That is the point: a file outside the folders is a file that was never filed.

The entries use the same shapes as [nix-community/impermanence](https://github.com/nix-community/impermanence)
(`"path"` or `{ directory; mode; }`, relative to the home), so they can be handed to
`environment.persistence."/persist".users.v1cferr` as they are.

## `persist-diff`: what would be lost

```sh
persist-diff            # every path in ~ the list does not cover, biggest first, plus a total
```

It walks the home, descends only into folders that hold a persisted path, and skips what comes back
on its own: home-manager links into the store, folders made only of them, and the rclone mounts.
Read-only, about 8 s.

MEASURED on 28/10/2026, with the list as committed: **41 GiB in 143 paths** would not survive.
19 GiB of it is `~/.cache`, and most of the rest is other caches (pnpm, npm, cargo,
`.vscode-server`), the Chrome stable profile (the app is no longer installed) and leftovers of apps
removed long ago. The run is also what surfaced the cases the list must not miss:

- **Hand-written user units**: the `acuttis-point*` services and timers in
  `~/.config/systemd/user` are not declared anywhere, so they would vanish. They belong in Nix
  before the switch, not in this list (home-manager owns that folder).
- **Loose secrets** at the root of the home (`age-backup-key.txt`, `wg0.conf`, a router backup):
  they belong in the Bitwarden vault or sops, not in a persisted folder.

The rule for switching on: run it, and when what it prints is only garbage for a few weeks running,
the list is right.

## Turning it on (later, and only when I decide)

1. Add `nix-community/impermanence` as a flake input and import its NixOS module.
2. Root first: wipe `@` at boot from a blank snapshot and declare the system list (`/var/lib`, the
   machine id, NetworkManager connections and so on). That list does not exist yet.
3. Home after: hand `config.home-manager.users.v1cferr.my.persist` to
   `environment.persistence."/persist".users.v1cferr`, move the data into `/persist/home/v1cferr`
   once, and only then wipe `@home`.

Two things to settle at step 3: the nested subvolumes from `home-subvolumes.nix` (game libraries and
VM images) need their own answer, because a bind mount over a subvolume is not the same as keeping
it, and a persisted folder is not a backed-up one (`~/Downloads` is still outside restic).
