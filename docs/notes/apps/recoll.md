# Recoll: search the PC by content, not only by name

`modules/home/apps/recoll.nix`.

## Why it exists

Dolphin stays the file manager (KIO mounts, the Kvantum Win11 theme, the Ark menus, the
Explorer layout, see [`dolphin.md`](dolphin.md)). yazi is already in `modules/home/shell/cli.nix`
and its `s` (fd) and `S` (ripgrep) search by name and by content, but only from the current
folder, with no index, and ripgrep reads TEXT: a PDF or a `.docx` is invisible to it.

The searches here are both kinds: code and text, and documents (PDF, Office). Recoll covers both
with a Xapian index: plain text and source, PDF, docx/xlsx/odt, and inside zip files.

## Why not Baloo

Baloo is KDE's indexer and Dolphin's search uses it, but outside Plasma it has no settings page:
it is configured through `balooctl6` and a mutable `baloofilerc` that KDE rewrites, the same fight
`dolphin.md` describes for `dolphinrc`. Recoll is a home-manager module (`services.recoll`), so
the whole config is declarative, and its GUI is Qt, so Kvantum themes it like Dolphin.

## What gets indexed, and what never does

`topdirs` lists only where documents and code live (`~/Documents`, `~/Dropbox`, `~/Downloads`,
`~/Projects`, `~/Desktop`). The home is ~194 GB, mostly caches and games, and none of the mounts
(`~/FAI-workstation` over rclone, `/mnt/*`) is under a topdir, so a slow or dead network never
stalls the indexer.

**THE INDEX STORES THE EXTRACTED TEXT IN CLEAR** (under `~/.cache/recoll`), so a file holding a
secret must not enter it, or the secret ends up copied outside the file's own permissions.
`skippedNames+` drops `.env` files, `*.age`, `*api_keys*`, `*key*.txt` and `Backup-codes*`, which
matches the real files in `~/Documents` and `~/Dropbox`. A NEW secret file with a name outside
those patterns WILL be indexed: name it to match, or add its pattern.

`skippedPaths` drops folders under a topdir that are big archives (`~/Downloads/Jogos`,
`~/Downloads/minecraft-server`; Recoll opens zip files) or sensitive (`~/Downloads/Seguranca`). It
replaces Recoll's default (`/media`), which no topdir reaches anyway.

## Using it

- GUI: `recoll`. Words go in the box, the type filter narrows to PDF, text, office and so on.
- Terminal: `recollq 'term'`.
- The index runs hourly (`systemctl --user list-timers recollindex`) and only rereads changed
  files. To refresh now: `systemctl --user start recollindex`.
- Quick code search inside one repo is still faster with `S` in yazi or `rg`.
