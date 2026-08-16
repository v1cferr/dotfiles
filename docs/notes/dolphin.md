# Dolphin: forcing keys that the app itself rewrites

`home/apps/dolphin.nix`.

## Why an activation script and not a managed file

Dolphin REWRITES its KConfig at runtime, so an immutable home-manager symlink would break the other
prefs (window size and so on). Instead of managing the file, an activation script forces ONLY the
keys we want, idempotently, and leaves the rest mutable.

The same reasoning applies to the Places panel: Dolphin rewrites `user-places.xbel` at runtime
(mounting a disk, adding a place), so a symlink would fight it and freeze your places.

## "Always Details" is two keys

```text
dolphinrc [General] GlobalViewProps=true                      -> the same mode in EVERY folder
view_properties/global/.directory [Dolphin] ViewMode=1        -> 1 = Details
```

**THE VALUE DOES NOT FOLLOW THE MENU ORDER.** It was `2` here from 18/07 to 07/08/2026 and the
effect was Compact: the pin worked, it just pointed at the wrong mode, and being immutable,
switching to Details in the session never stuck.

The enum is `DolphinView::Mode` (`src/views/dolphinview.h`): 0 = Icons, 1 = Details, 2 = Compact.
The menu lists Icons/Compact/Details (Ctrl+1/2/3), which is a DIFFERENT order, and the kcfg's
`whatsthis` makes it worse by calling 2 "column" (Compact's old name). Check the source header,
never the menu and never the kcfg.

## Why `ViewMode` goes in immutable

As `ViewMode[$i]=1`, KConfig's kiosk marker. This is not fussiness.

Since 26.04 Dolphin stores the view properties in a directory xattr
(`user.kde.fm.viewproperties#1`) and treats the `.directory` as legacy, so its `save()` calls
`cleanDotDirectoryFile()`, which does `deleteGroup("Dolphin")` and DELETES the file
(`viewproperties.cpp`).

Only the marker survives that: KConfig refuses the removal, the group does not end up empty, and
the file stays. And since the `.directory` takes precedence over the xattr on READ, it is the
declarative anchor. Dolphin even copies the `[$i]` into the xattr on the first save.

The other props (sorting, columns, thumbnails) stay mutable. Changing the mode in the session
works, it just does not persist.

### The three-branch guard

`kwriteconfig6` does not know how to write the `[$i]` marker, so it writes the normal key (which
creates and positions the right group) and `sed` promotes it to immutable. The guard is MANDATORY:
over an already immutable key `kwriteconfig6` exits 2, and the activation runs with `set -e`, so it
would abort the rest of home-manager. The three cases are: already right, already immutable but
with ANOTHER value (the 2 to 1 case, rewritten with sed), and not there yet.

## The icon size, and why it is `PreviewSize`

Without setting it, the folders come out as monochrome LINE ART instead of the yellow Windows 11
ones. The Win11 theme only has colored art in `places/16` and `places/scalable`, since `places/22`
is `fill="currentColor"`, and 22 is precisely the default. Fluent had the same monochrome 22; it
just did not show, because the view was Compact, which asks for a big icon and fell into scalable.

**THE KEY IS `PreviewSize`, NOT `IconSize`**, and that cost two wrong attempts. With previews ON
(our case, decided 07/08) Dolphin ignores `IconSize`:

```cpp
// dolphinitemlistview.cpp:172
const int iconSize = previewsShown() ? settings.previewSize() : settings.iconSize();
```

Both go to 32 on purpose, so the size does not jump when previews are turned off to dig through
`/mnt/arch-antigo`. 32 is a valid `ZoomLevelInfo` step (16/22/32/48/…) and the first one that
enters the `places/scalable` range (`MinSize=32`).

It does NOT go in immutable, so Ctrl+scroll keeps working in the session. A zoom that stops at 22
brings the line art back, which is the price of leaving the zoom free.

## Parity with Windows Explorer (07/08/2026)

Only the keys where Dolphin's default DIVERGES from Explorer's, and each default was checked in the
package's `config.kcfg`, not guessed. `HighlightEntireRow` and `SortFoldersFirst` already come
right and stay out.

| Key | Why |
| --- | --- |
| `DetailsMode/ExpandableFolders=false` | the `▶` markers and tree lines are the most jarring difference; Explorer has no expander in that view |
| `General/ShowSelectionToggle=false` | the hover selection marker; on Win11 "item check boxes" comes OFF |
| `General/AlwaysShowTabBar=true` | Win11 Explorer shows the tab strip even with a single tab |
| `General/ShowFullPath=true` | an address bar with the full path, not just the folder name |
| `General/ShowStatusBar=FullWidth` | a KConfigXT enum: write the choice's NAME, not the index |

The "pixel-perfect" guide that circulates in the community was NOT followed
(vrunox-9714/dolphin-win11-theme): it depends on a KWIN RULE to remove the title bar, and here it
is Hyprland so there is no KWin, and on a QSS through `--stylesheet`, which would fight the Kvantum
that already draws all of Qt here. What is left applicable from it is toolbar layout, which is
`dolphinui.rc` and not a key.

**`[KDE] SingleClick=false` was TRIED and REMOVED** on 07/08/2026. The request is INTERFACE
similarity, and clicking is BEHAVIOR, so it does not change a pixel. Worse: it lives in
`kdeglobals`, so it would change every KDE app because of the file manager. Do not reintroduce it.

## The Places panel

Adding a place is 1 line in the `places` list. The icon names were checked against breeze-icons
6.26.0 (`places/22`); a name that does not exist breaks nothing, it just falls back to a generic
folder icon. Each bookmark gets its own XBEL file, and KDE's `<ID>` comes from the list INDEX, so
it is unique with no magic number repeated by hand.

The test is PER PLACE and matches by PATH, not against the whole list: with a single guard, a new
place would never enter (the file would already have the old one) or the old ones would duplicate.
There is no `exit` in the script on purpose, because home-manager's activation is a single script
and an `exit` would abort everything after it. It also does not hardcode the disk entries, which
are hardware specific, so it stays reproducible on any machine.

Two of the places deserve their own note:

- **Backup (snapshots)**, `/mnt/backup`: only has content WITH THE MOUNT UP (`backup-browse`).
  Empty means not mounted, and that is information, not a bug. It is a rare lookup, and a permanent
  mount of the HOME repo would be a stuck lock on top of the repo the daily prune NEEDS to lock by
  itself. Contrast with `/mnt/arch-antigo`, which IS permanent since 11/08/2026 because that repo
  is static and needs no lock; see [`arch-legacy.md`](arch-legacy.md). There, an empty folder is a
  real SYMPTOM: `systemctl --user status arch-antigo-mount`.
- **"Arch antigo"** keeps its pt-BR title on purpose. The bookmark is matched by PATH, so renaming
  it would only affect a NEW insertion and would leave the declared title diverging from the one
  already in `user-places.xbel`. It is the same runtime identifier as `/mnt/arch-antigo`.

## The packages

`dolphin` plus the extras that enable features: `kio-extras` gives SFTP/SMB/MTP (a phone over USB),
the thumbnailers give image, pdf and video previews, and `ark` adds the archive manager plus the
"Compress/Extract" servicemenus on right click. The trash (`trash:/`) is native.
