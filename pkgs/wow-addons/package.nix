# wow-addons: every WoW Forever add-on in sources.json, unpacked into one tree of AddOns folders.
# The list, the sources and how it reaches the game: docs/notes/apps/wow-addons.md
{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  callPackage,
}:

let
  # name -> { source, projectId | repo, version, url, hash }: the ONLY file the bump writes.
  sources = lib.importJSON ./sources.json;

  zips = lib.mapAttrs (
    name: s:
    fetchurl {
      inherit (s) url hash;
      name = "${name}.zip"; # the upstream filename may hold `!` or spaces, which a store name rejects
    }
  ) sources;
in
stdenvNoCC.mkDerivation {
  pname = "wow-addons";
  version = "1.60.1"; # the Forever client these files target; each add-on's own version is in sources.json
  dontUnpack = true;
  nativeBuildInputs = [ unzip ];

  # Two zips shipping the same folder would overwrite each other in silence, so that FAILS instead.
  installPhase = ''
    mkdir -p $out
  ''
  + lib.concatStrings (
    lib.mapAttrsToList (name: zip: ''
      mkdir "$TMPDIR/${name}"
      unzip -q ${zip} -d "$TMPDIR/${name}"
      for dir in "$TMPDIR/${name}"/*/; do
        folder=$(basename "$dir")
        if [ -e "$out/$folder" ]; then
          echo "wow-addons: ${name} ships '$folder', which another add-on already provides" >&2
          exit 1
        fi
        cp -r "$dir" "$out/$folder"
      done
    '') zips
  )
  # Upstream ships ONE zip for every flavour (DBM's Midnight raids),
  # and the game lists those folders as incompatible. A folder whose TOCs declare no Forever
  # support (interface 160xx, a _Forever/_Camelot TOC, or AllowLoadGameType) is dropped. Pawn's
  # TOC starts with a UTF-8 BOM, hence the optional EF BB BF before `##`.
  + ''
    bom=$'\xEF\xBB\xBF'
    shopt -s nullglob
    for dir in "$out"/*/; do
      tocs=("$dir"*.toc)
      if [ -n "$(echo "$dir"*_Forever.toc "$dir"*_Camelot.toc)" ] ||
        LC_ALL=C grep -qsE "^($bom)?## Interface:.*\b160[0-9]{2}\b" "''${tocs[@]}" ||
        LC_ALL=C grep -qsiE "^($bom)?## AllowLoadGameType:.*forever" "''${tocs[@]}"; then
        continue
      fi
      echo "wow-addons: dropping $(basename "$dir"), no Forever TOC"
      rm -rf "$dir"
    done
  ''
  # A REQUIRED dependency missing from the list FAILS the build. Read from the TOC the Forever client
  # loads (_Forever, then _Camelot, then the plain one); Blizzard_ modules ship with the game. It
  # cannot catch a dependency enforced only at run time: Baganator listed Syndicator as OPTIONAL and
  # then raised a Lua error without it, so a new add-on still gets one /reload with BugSack.
  + ''
    missing=0
    for dir in "$out"/*/; do
      name=$(basename "$dir")
      toc=""
      for candidate in "$dir$name"_Forever.toc "$dir$name"_Camelot.toc "$dir$name".toc; do
        [ -f "$candidate" ] && { toc=$candidate; break; }
      done
      [ -n "$toc" ] || continue
      deps=$(LC_ALL=C sed -nE "s/^($bom)?## *(RequiredDeps|Dependencies|Dep[A-Za-z0-9]*): *//Ip" "$toc" |
        tr ',' '\n' | tr -d ' \r')
      for dep in $deps; do
        case "$dep" in Blizzard_*) continue ;; esac
        if ! ls "$out" | grep -qixF "$dep"; then
          echo "wow-addons: $name requires $dep, which is not in sources.json" >&2
          missing=1
        fi
      done
    done
    [ "$missing" -eq 0 ]
  '';

  passthru.updateScript = callPackage ./bump.nix { };

  meta = {
    description = "WoW Forever add-ons, each pinned to its latest stable release";
    platforms = lib.platforms.all;
  };
}
