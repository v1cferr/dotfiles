# Downloads tidy: the root of ~/Downloads is an inbox

`modules/home/services/downloads-tidy.nix`.

## Why this exists

MEASURED on 28/10/2026, `~/Downloads` held 34 GiB: 18 folders sorted by hand (UFSCAR, Financeiro,
CVs and so on) and 26 files loose at the root, from PDFs to a 9.5 GiB game zip and a NixOS ISO. The
folders were fine. The root was a pile, because sorting by hand only happens when the pile hurts.

## The model

The root is an INBOX, a place things land and leave. Every 30 min a user timer moves each loose
file that sat untouched for an hour into one folder per type, inside `~/Downloads` itself:

| Folder | Extensions |
| --- | --- |
| `Archives` | zip rar 7z tar gz xz zst bz2 |
| `Audio` | mp3 opus flac ogg wav m4a |
| `Code` | json xml html yml yaml toml sh py nix |
| `Disk-images` | iso img qcow2, plus the `.iso.sha256` and `.iso.sig` that verify them |
| `Documents` | pdf doc docx odt rtf txt md epub |
| `Images` | png jpg jpeg webp gif svg heic avif |
| `Installers` | deb rpm apk appimage exe msi |
| `Spreadsheets` | xls xlsx ods csv |
| `Video` | mp4 mkv webm mov avi |
| `Other` | anything unmatched |

The table lives in `my.downloads.buckets`; a new extension is one word there.

What it never touches:

- **Folders.** Only `-maxdepth 1 -type f`, so the hand-made folders (and `mega/`, which
  `modules/home/network/mega.nix` downloads into) stay exactly as they are.
- **Running downloads.** `.part`, `.crdownload`, `.download`, `.tmp` and hidden files are skipped,
  and a file must be older than `settleMinutes` (60) in BOTH mtime and ctime. ctime matters because
  a browser may stamp the server's old mtime on a file that landed a second ago.
- **Existing files.** A clash becomes `name (2).ext`, and `mv -n` guards the race.

## The trash window

Installers and disk images can be downloaded again, so files in `Installers/` and `Disk-images/`
go to the trash (`trash-put`, never `rm`) `trashAfterDays` (30) after they were SORTED. The clock is
ctime, which the move resets, so a `.deb` whose server says 2019 does not vanish on arrival.

`~/Downloads` is outside restic (`modules/nixos/services/restic.nix`), so the trash is the only
safety net. `trash-expire` ([disk-hygiene](disk-hygiene.md)) empties it after 30 more days: an
installer is recoverable for **60 days** after it was sorted. Nothing else is ever deleted.

## Why not a ready-made tool

Checked on 28/10/2026 against rule 24's ladder:

- [organize](https://github.com/tfeldmann/organize) is the reference (YAML rules, a `sim` dry run),
  but it is not in nixpkgs. Packaging a Python app with its dependency tree for ~60 lines of logic
  is the wrong trade.
- relfa (age-based archiving) is young and not packaged either.
- User `systemd-tmpfiles` rules only DELETE; they cannot sort.

So the rules are Nix (rung 1) generating a `case` in shell glue (rung 3).

## The journal

48 runs a day would bury the journal in systemd's Starting/Finished lines, the
[disk-hygiene](disk-hygiene.md) lesson. `SyslogLevel = notice` plus `LogLevelMax = notice` keeps
the script's own `moved:` and `trashed:` lines and cuts systemd's info-level noise. No desktop
notification: one every 30 min is noise too.

## Operating it

```sh
downloads-tidy --dry-run                 # what it would move and trash, touching nothing
journalctl --user -u downloads-tidy      # what it did
systemctl --user list-timers downloads-tidy
```

To undo a move, the journal line names the source and the destination. To stop it,
`systemctl --user stop downloads-tidy.timer` (until the next switch) or drop the import from
`modules/home/services/default.nix`.
