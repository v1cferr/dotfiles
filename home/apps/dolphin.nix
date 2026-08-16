# DOLPHIN (KDE): the view mode always "Details", declared.
#
# Dolphin REWRITES its KConfig at runtime, so an immutable home-manager symlink would break the
# other prefs (window size and so on). So instead of managing the file, an activation script
# forces ONLY the keys we want (idempotently), leaving the rest mutable for Dolphin.
#
# "Always Details" is two keys:
#   dolphinrc [General] GlobalViewProps=true  -> the same mode in EVERY folder
#   view_properties/global/.directory [Dolphin] ViewMode=1  -> 1 = Details
#
# THE VALUE DOES NOT FOLLOW THE MENU ORDER. It was 2 here from 18/07 to 07/08/2026 and the
# effect was Compact: the pin worked, it just pointed at the wrong mode, and being immutable,
# switching to Details in the session never stuck. The enum is `DolphinView::Mode`
# (src/views/dolphinview.h): 0 = Icons, 1 = Details, 2 = Compact. The menu lists
# Icons/Compact/Details (Ctrl+1/2/3), which is a different order, and the kcfg's `whatsthis`
# makes it worse by calling 2 "column" (Compact's old name). Check the source header, never the
# menu and never the kcfg.
#
# And the ViewMode goes in IMMUTABLE, as `ViewMode[$i]=2`, KConfig's kiosk marker. It is not
# fussiness: since 26.04 Dolphin stores the view properties in a directory xattr
# (user.kde.fm.viewproperties#1) and treats the .directory as legacy, so its save() calls
# cleanDotDirectoryFile(), which does deleteGroup("Dolphin") and DELETES the file
# (viewproperties.cpp). Only the marker survives that: KConfig refuses the removal, the group
# does not end up empty, and the file stays. And since the .directory takes precedence over the
# xattr on read, it is the declarative anchor. Dolphin even copies the `[$i]` into the xattr on
# the first save.
#
# The other props (sorting, columns, thumbnails) stay mutable. Changing the mode in the session
# works, it just does not persist; to change it for good, edit here.
# ═══════════════════════════════════════════════════════════════════════════
{
  pkgs,
  lib,
  config,
  osConfig,
  ...
}:

let
  # `DolphinView::Mode` (src/views/dolphinview.h): 0 = Icons, 1 = Details, 2 = Compact.
  # Named because the raw number is a TRAP, see the header.
  viewModeDetails = 1;

  # FIXED PLACES in Dolphin's Places panel. Adding one is 1 line in this list.
  # The icon names were checked against breeze-icons 6.26.0 (places/22): a name that does not
  # exist breaks nothing, it just falls back to a generic folder icon.
  places = [
    {
      title = "FAI Workstation";
      path = "/home/v1cferr/FAI-workstation"; # rclone SFTP; it comes up with the FAI VPN
      icon = "folder-remote";
    }
    {
      title = "Obsidian";
      path = "/home/v1cferr/Dropbox/Obsidian"; # the notes vault (synced by Dropbox)
      icon = "folder-notes";
    }
    {
      title = "Drive";
      path = config.my.drive.local; # SSOT: home/services/drive-mount.nix (rule 11)
      icon = "folder-gdrive";
    }
    # This one only has content WITH THE MOUNT UP (`backup-browse`). Empty means not mounted,
    # and that is information, not a bug: it is a rare lookup, and a permanent mount of the HOME
    # repo would still be a stuck lock on top of the repo the daily prune NEEDS to lock by
    # itself.
    {
      title = "Backup (snapshots)";
      path = "/mnt/backup"; # the home repo on the Drive; read-only, one dir per snapshot
      icon = "folder-tar";
    }
    # This one, by contrast, is ALWAYS mounted since 11/08/2026
    # (home/services/arch-legacy-mount.nix): the repo is static and the mount needs no lock, so
    # all that was left was the RAM cost. An empty folder here became a real SYMPTOM:
    # `systemctl --user status arch-antigo-mount`.
    # The title stays in pt-BR on purpose: the bookmark is matched by PATH below, so renaming it
    # would only affect a NEW insertion and would leave the declared title diverging from the
    # one already in user-places.xbel. It is the same runtime identifier as /mnt/arch-antigo.
    {
      title = "Arch antigo";
      path = osConfig.my.archAntigo.local; # SSOT: system/services/arch-legacy.nix (rule 11)
      icon = "folder-locked";
    }
  ];

  # One XBEL file per place. KDE's `<ID>` has to be UNIQUE per bookmark, and it comes from the
  # index, so there is no collision and no magic number repeated by hand.
  placeFiles = lib.imap0 (
    i: p:
    p
    // {
      file = pkgs.writeText "dolphin-place-${toString i}.xbel" ''
        <bookmark href="file://${p.path}">
         <title>${p.title}</title>
         <info>
          <metadata owner="http://freedesktop.org">
           <bookmark:icon name="${p.icon}"/>
          </metadata>
          <metadata owner="http://www.kde.org">
           <ID>1784500000/${toString i}</ID>
           <isSystemItem>false</isSystemItem>
          </metadata>
         </info>
        </bookmark>
      '';
    }
  ) places;
in
{
  # Dolphin (KDE) plus extras that enable features: kio-extras gives SFTP/SMB/MTP (a phone over
  # USB); the thumbnailers give image, pdf and video previews. The trash (trash:/) is native.
  home.packages = with pkgs.kdePackages; [
    dolphin
    kio-extras
    kdegraphics-thumbnailers
    ffmpegthumbs
    ark # an archive manager plus the "Compress/Extract" servicemenus on right click
  ];

  home.activation.dolphinDetailsView = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kw="${pkgs.kdePackages.kconfig}/bin/kwriteconfig6"
    run "$kw" --file "$HOME/.config/dolphinrc" --group General --key GlobalViewProps true

    # The ICON SIZE in the Details view. Without this the folders come out as monochrome LINE
    # ART instead of the yellow Windows 11 ones: the Win11 theme only has colored art in
    # `places/16` and `places/scalable`, since `places/22` is `fill="currentColor"`, and 22 is
    # precisely the default. (Fluent had the same monochrome 22; it just did not show because
    # the view was Compact, which asks for a big icon and fell into scalable.)
    #
    # THE KEY IS `PreviewSize`, NOT `IconSize`, and that cost two wrong attempts. With previews
    # ON (our case, decided on 07/08) Dolphin ignores `IconSize`:
    #   dolphinitemlistview.cpp:172
    #   const int iconSize = previewsShown() ? settings.previewSize() : settings.iconSize();
    # Both go to 32 on purpose, so the size does not jump when previews are turned off to dig
    # through /mnt/arch-antigo. 32 is a valid ZoomLevelInfo step (16/22/32/48/…) and the 1st one
    # that enters the `places/scalable` range (MinSize=32).
    # It does NOT go in immutable: that way Ctrl+scroll keeps working in the session. A zoom
    # that stops at 22 brings the line art back, which is the price of leaving the zoom free.
    run "$kw" --file "$HOME/.config/dolphinrc" --group DetailsMode --key PreviewSize 32
    run "$kw" --file "$HOME/.config/dolphinrc" --group DetailsMode --key IconSize 32

    # ── PARITY WITH WINDOWS EXPLORER (07/08/2026) ───────────────────────────────────
    # Only the keys where Dolphin's default DIVERGES from Explorer's, and each default was
    # checked in the package's config.kcfg, not guessed. `HighlightEntireRow` (the whole row
    # highlighted) and `SortFoldersFirst` (folders first) already come right and stay out.
    #
    # The "pixel-perfect" guide that circulates in the community was NOT followed
    # (vrunox-9714/dolphin-win11-theme): it depends on a KWIN RULE to remove the title bar, and
    # here it is Hyprland, so there is no KWin, and on a QSS through `--stylesheet`, which would
    # fight the Kvantum that already draws all of Qt here.
    # What is left applicable from it is toolbar layout, which is `dolphinui.rc` and not a key.

    # The `▶` markers and the tree lines in Details are the MOST jarring thing next to Explorer,
    # which has no expander at all in that view.
    run "$kw" --file "$HOME/.config/dolphinrc" --group DetailsMode --key ExpandableFolders false
    # The selection marker that appears on hover. On Win11 "item check boxes" comes OFF; in
    # Dolphin it comes on.
    run "$kw" --file "$HOME/.config/dolphinrc" --group General --key ShowSelectionToggle false
    # The Win11 Explorer shows the tab strip even with a single tab.
    run "$kw" --file "$HOME/.config/dolphinrc" --group General --key AlwaysShowTabBar true
    # An address bar with the full path, not just the current folder's name.
    run "$kw" --file "$HOME/.config/dolphinrc" --group General --key ShowFullPath true
    # A KConfigXT enum: you write the choice's NAME (Small/FullWidth/Disabled), not the index.
    run "$kw" --file "$HOME/.config/dolphinrc" --group General --key ShowStatusBar FullWidth

    # `[KDE] SingleClick=false` (double click) was TRIED and REMOVED on 07/08/2026. The request
    # is INTERFACE similarity, and clicking is BEHAVIOR, so it does not change a pixel. Worse:
    # it lives in kdeglobals, so it would change every KDE app because of the file manager. Do
    # not reintroduce it.

    dir="$HOME/.local/share/dolphin/view_properties/global"
    run mkdir -p "$dir"
    run "$kw" --file "$dir/.directory" --group Dolphin --key Version 4
    # kwriteconfig6 does not know how to write the [$i] marker, so it writes the normal key (it
    # creates and positions the right group) and sed promotes it to immutable. The guard is
    # mandatory: over an already immutable key kwriteconfig6 exits 2, and the activation runs
    # with `set -e`, so it would abort the rest of home-manager.
    if grep -qF 'ViewMode[$i]=${toString viewModeDetails}' "$dir/.directory" 2>/dev/null; then
      : # already at the right value and immutable
    elif grep -qF 'ViewMode[$i]=' "$dir/.directory" 2>/dev/null; then
      # Already immutable, but with ANOTHER value, which is the 2 to 1 case. Here kwriteconfig6
      # would exit 2 and take the activation down, so the line is rewritten directly.
      run ${pkgs.gnused}/bin/sed -i \
        's/^ViewMode\[\$i\]=.*$/ViewMode[$i]=${toString viewModeDetails}/' "$dir/.directory"
    else
      run "$kw" --file "$dir/.directory" --group Dolphin --key ViewMode ${toString viewModeDetails}
      run ${pkgs.gnused}/bin/sed -i \
        's/^ViewMode=${toString viewModeDetails}$/ViewMode[$i]=${toString viewModeDetails}/' "$dir/.directory"
    fi
  '';

  # Bookmarks in the Places panel (declarative, idempotent). The SAME reason as the details
  # view: Dolphin rewrites user-places.xbel at runtime (mounting a disk, adding a place), so an
  # immutable symlink would fight it and freeze your places. So it inserts each bookmark ONLY if
  # it is not there yet, leaving the rest mutable. Reproducible on any machine (it does not
  # hardcode the disk entries, which are hardware specific).
  #
  # The test is PER PLACE and matches by PATH, not by the whole list: with a single guard, a new
  # place would never enter (the file would already have the old one) or the old ones would
  # duplicate. No `exit` here on purpose, because home-manager's activation is a single script
  # and an `exit` would abort everything that comes after.
  home.activation.dolphinPlaces = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    xbel="$HOME/.local/share/user-places.xbel"
    ${lib.concatMapStrings (p: ''
      if [ -f "$xbel" ] && ! grep -qF '${p.path}' "$xbel"; then
        tmp="$(mktemp)"
        grep -v '</xbel>' "$xbel" > "$tmp"
        cat ${p.file} >> "$tmp"
        printf '</xbel>\n' >> "$tmp"
        run mv "$tmp" "$xbel"
      fi
    '') placeFiles}
  '';
}
