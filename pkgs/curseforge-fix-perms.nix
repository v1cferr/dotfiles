# curseforge-fix-perms: restores the exec bit the CurseForge extractor drops on what it unpacks.
# The 115 files it found, and why ELF magic and not names: docs/notes/apps/curseforge-fix-perms.md
{
  writeShellApplication,
  findutils,
  coreutils,
}:

writeShellApplication {
  name = "curseforge-fix-perms";
  runtimeInputs = [
    findutils
    coreutils
  ];

  # set -euo pipefail already comes from writeShellApplication (default bashOptions).
  text = ''
    # Path by ARGUMENT: testable without touching the real tree.
    root="''${1:-$HOME/Documents/curseforge/minecraft/Install}"
    root="''${root%/}" # a trailing slash would break the -path of the prune below

    # Silent when nothing was downloaded yet: this runs on every activation.
    [ -d "$root" ] || exit 0

    broken=()
    while IFS= read -r -d "" file; do
      # The 4-byte ELF magic, read by bash. `|| true`: a file under 4 bytes fails `read`.
      magic=""
      IFS= read -r -n4 magic < "$file" 2>/dev/null || true
      if [ "$magic" = $'\x7fELF' ]; then
        broken+=("$file")
      fi
    done < <(find "$root" -path "$root/assets" -prune -o -type f ! -perm -u+x -print0)

    [ ''${#broken[@]} -gt 0 ] || exit 0

    chmod +x "''${broken[@]}"
    echo "curseforge-fix-perms: +x on ''${#broken[@]} file(s) under $root"
  '';

  meta = {
    description = "Restores the exec bit that the CurseForge extractor drops on what the app downloads";
    mainProgram = "curseforge-fix-perms";
  };
}
