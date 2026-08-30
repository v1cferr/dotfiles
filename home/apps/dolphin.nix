# DOLPHIN: the keys forced by an ACTIVATION script, because Dolphin rewrites its own KConfig and
# a managed symlink would fight it. The ViewMode trap and the Win11: docs/notes/apps/dolphin.md
{
  pkgs,
  lib,
  config,
  osConfig,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs) gnused writeText;
  inherit (pkgs.kdePackages) kconfig; # kwriteconfig6, the activation's only tool

  # `DolphinView::Mode` (dolphinview.h): 0 = Icons, 1 = Details, 2 = Compact. Named because the
  # raw number is a TRAP: the MENU lists them in another order. See the notes.
  viewModeDetails = 1;

  # An IMMUTABLE view property (`Key[$i]`), the ONLY kind that survives Dolphin's own
  # cleanDotDirectoryFile(). The 3-branch guard and the sed promotion: docs/notes/apps/dolphin.md
  immutableViewProp = group: key: value: ''
    if grep -qF '${key}[$i]=${value}' "$dir/.directory" 2>/dev/null; then
      : # already at the right value and immutable
    elif grep -qF '${key}[$i]=' "$dir/.directory" 2>/dev/null; then
      # Immutable with ANOTHER value: kwriteconfig6 would exit 2, so rewrite it with sed.
      run ${gnused}/bin/sed -i \
        's/^${key}\[\$i\]=.*$/${key}[$i]=${value}/' "$dir/.directory"
    else
      run "$kw" --file "$dir/.directory" --group ${group} --key ${key} ${value}
      run ${gnused}/bin/sed -i \
        's/^${key}=${value}$/${key}[$i]=${value}/' "$dir/.directory"
    fi
  '';

  # FIXED PLACES. Adding one is 1 line here; a wrong icon name only falls back to a generic one.
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
    # Empty means NOT mounted, and that is information: a permanent mount of the HOME repo would
    # hold a lock the daily prune needs for itself. See docs/notes/apps/dolphin.md
    {
      title = "Backup (snapshots)";
      path = "/mnt/backup"; # the home repo on the Drive; read-only, one dir per snapshot
      icon = "folder-tar";
    }
    # This one IS permanent since 11/08/2026, so an empty folder here is a real SYMPTOM. The
    # pt-BR title stays: the bookmark is matched by PATH, so renaming it would only diverge.
    {
      title = "Arch antigo";
      path = osConfig.my.archAntigo.local; # SSOT: system/services/arch-legacy.nix (rule 11)
      icon = "folder-locked";
    }
    # APPEND, never insert: the KDE <ID> below comes from the INDEX, so a new entry in the middle
    # would collide with the id of a bookmark already written into the user's xbel.
    {
      title = "Context";
      path = config.my.memory.dir; # SSOT: home/services/basic-memory.nix (rule 11)
      # `folder-database` and not `folder-library`/`folder-book`: those two are symlinks to ACTION
      # icons at 22px (an institution, an address book), so they break the folder look.
      icon = "folder-database";
    }
  ];

  # One XBEL file per place. KDE's <ID> comes from the INDEX, so it is unique with no magic
  # number typed by hand.
  placeFiles = lib.imap0 (
    i: p:
    p
    // {
      file = writeText "dolphin-place-${toString i}.xbel" ''
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
  # Dolphin plus the extras that enable features: kio-extras (SFTP/SMB/MTP) and the thumbnailers.
  home.packages = with pkgs.kdePackages; [
    dolphin
    kio-extras
    kdegraphics-thumbnailers
    ffmpegthumbs
    ark # an archive manager plus the "Compress/Extract" servicemenus on right click
  ];

  home.activation.dolphinDetailsView = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kw="${kconfig}/bin/kwriteconfig6"
    run "$kw" --file "$HOME/.config/dolphinrc" --group General --key GlobalViewProps true

    # THE KEY IS `PreviewSize`, NOT `IconSize` (dolphinitemlistview.cpp:172), and 32 is the first
    # step that reaches places/scalable, without which the folders come out as line art.
    run "$kw" --file "$HOME/.config/dolphinrc" --group DetailsMode --key PreviewSize 32
    run "$kw" --file "$HOME/.config/dolphinrc" --group DetailsMode --key IconSize 32

    # PARITY WITH EXPLORER: only the keys where Dolphin's default DIVERGES, each one checked in
    # config.kcfg. What was tried and REMOVED (SingleClick) is in the notes.

    # The `▶` markers and tree lines: Explorer has no expander in this view at all.
    run "$kw" --file "$HOME/.config/dolphinrc" --group DetailsMode --key ExpandableFolders false
    # The hover selection marker: on Win11 "item check boxes" comes OFF.
    run "$kw" --file "$HOME/.config/dolphinrc" --group General --key ShowSelectionToggle false
    # Win11 Explorer shows the tab strip even with a single tab.
    run "$kw" --file "$HOME/.config/dolphinrc" --group General --key AlwaysShowTabBar true
    # An address bar with the full path, not just the folder's name.
    run "$kw" --file "$HOME/.config/dolphinrc" --group General --key ShowFullPath true
    # A KConfigXT enum: write the choice's NAME, not the index.
    run "$kw" --file "$HOME/.config/dolphinrc" --group General --key ShowStatusBar FullWidth

    # SingleClick was TRIED and REMOVED (07/08/2026): it is BEHAVIOR, not a pixel, and it lives in
    # kdeglobals, so it would change every KDE app. Do not reintroduce it.

    dir="$HOME/.local/share/dolphin/view_properties/global"
    run mkdir -p "$dir"
    run "$kw" --file "$dir/.directory" --group Dolphin --key Version 4
    ${immutableViewProp "Dolphin" "ViewMode" (toString viewModeDetails)}
    # HIDDEN FILES always on, and immutable for the same reason as ViewMode: save() deletes the
    # `[Settings]` group too, so only the marker keeps the key alive.
    ${immutableViewProp "Settings" "HiddenFilesShown" "true"}
  '';

  # "Open Terminal Here": with NO key KTerminalLauncherJob falls back to konsole and then to
  # xterm, which is what was opening. kdeglobals is KDE-wide; see docs/notes/apps/dolphin.md
  home.activation.dolphinTerminalApp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kw="${kconfig}/bin/kwriteconfig6"
    # The bare NAME and never a store path: the file is mutable and would pin a dead kitty.
    run "$kw" --file "$HOME/.config/kdeglobals" --group General --key TerminalApplication kitty
  '';

  # The Places bookmarks: inserted only if the PATH is not there yet, so Dolphin keeps writing to
  # the file. Per place and not one guard for the list; and no `exit`, see the notes.
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
