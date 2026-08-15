# curseforge-bump: it keeps CurseForge on the latest version, with no editing pkgs/curseforge.nix
# by hand. A sibling of vscode-bump, and it exists for the SAME structural reason: a src with a
# locked hash never updates on its own; what exists is an AUTOMATED BUMP.
#
# The difference from vscode-bump: there we could use a versioned URL and the bump only changes
# the number. Here there is NO versioned URL (Overwolf only publishes
# `curseforge-latest-linux.AppImage`), so the hash is the only anchor, and it has to be
# RECOMPUTED, not just swapped. Without that, Overwolf's next release breaks
# `nix build .#curseforge` on any cold store (the file behind the URL changed).
#
# WHERE IT RUNS: in the `update`/`upgrade` alias (home/shell/zsh.nix), next to vscode-bump.
#
# WHY THE .deb DECIDES WHETHER IT CHANGED: downloading 139 MiB on every `update` just to find out
# nothing changed would be absurd, and there is no version API. The `.deb` of the SAME release
# carries the version in its `control`, which sits in the file's first few KiB, so a 256 KiB range
# request answers "did it change?" for ~0.2% of the cost. The AppImage is only downloaded when the
# answer is yes. Measured on 14/08/2026: both artifacts are published at the same instant and
# carry the same release (`1.316.0~37372-37372` in the .deb, `1.316.0-37372.37372` in
# X-AppImage-Version); the strings only differ in formatting, hence the normalization below. If
# they ever get out of sync, the worst case is downloading the AppImage for nothing: the script
# compares and rewrites, it does not break.
#
# THE TRAPS (the same ones as vscode-bump):
#   • The repo's path comes as an ARGUMENT, never a literal here (rule 11).
#   • `nix` does NOT go into runtimeInputs: it uses the system's, so as not to drag a second Nix
#     into the store with a version possibly diverging from the daemon's.
#   • It leaves the repo DIRTY on purpose, since the commit is the user's, atomic (rule 13).
#   • It is a NO-OP when already on the latest, because it runs on every `upgrade`.
{
  writeShellApplication,
  curl,
  gnused,
  gnutar,
  xz,
  binutils,
}:

writeShellApplication {
  name = "curseforge-bump";
  runtimeInputs = [
    curl
    gnused
    gnutar
    xz # the .deb's control.tar.xz; GNU tar autodetects the compression, but it needs the binary
    binutils # `ar`, since a .deb is an ar archive
  ];

  # set -euo pipefail already comes from writeShellApplication (the default bashOptions).
  text = ''
    repo="''${1:?usage: curseforge-bump <path-to-the-flake-repo>}"
    nix_file="$repo/pkgs/curseforge.nix"
    base="https://curseforge.overwolf.com/downloads"

    # The version LOCKED today: pkgs/curseforge.nix is its SSOT.
    current=$(sed -n 's|^  version = "\(.*\)";$|\1|p' "$nix_file")
    if [ -z "$current" ]; then
      echo "curseforge-bump: could not find the \`version\` in $nix_file" >&2
      echo "                 (did the package change shape? check pkgs/curseforge.nix)" >&2
      exit 1
    fi

    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    # ONLY the start of the .deb: the `control` lives before the `data.tar.*`, which is the whole
    # bulk.
    curl -fsSL -r 0-262143 -o "$tmp/head.deb" "$base/curseforge-latest-linux.deb"
    member=$(ar t "$tmp/head.deb" | sed -n '/^control\.tar/p' | head -1)
    if [ -z "$member" ]; then
      echo "curseforge-bump: the .deb has no control.tar* in the first 256 KiB" >&2
      exit 1
    fi
    # It goes through a FILE and not through a pipe on purpose: GNU tar only autodetects the
    # compression when it can seek, so `ar p … | tar -xO` dies with "Archive is compressed. Use -J
    # option" (measured). From a file it works it out on its own, which also lets the script
    # survive the day Overwolf swaps .xz for .zst.
    ar p "$tmp/head.deb" "$member" > "$tmp/control.tar"
    # `1.316.0~37372-37372` -> `1.316.0-37372`: the `~` becomes `-` and the repeated build at the
    # end drops off.
    latest=$(tar -xOf "$tmp/control.tar" ./control |
      sed -n 's|^Version: \(.*\)$|\1|p' | sed 's|~|-|; s|-[0-9]*$||')
    case "$latest" in
      *[!0-9.-]* | "")
        echo "curseforge-bump: the .deb returned an implausible version: '$latest'" >&2
        exit 1
        ;;
    esac

    if [ "$current" = "$latest" ]; then
      echo "curseforge-bump: already on the latest ($current)."
      exit 0
    fi

    echo "curseforge-bump: $current -> $latest (downloading the AppImage for the hash...)"
    curl -fsSL -o "$tmp/cf.AppImage" "$base/curseforge-latest-linux.AppImage"
    new_hash=$(nix hash file --type sha256 --sri "$tmp/cf.AppImage")

    # One `version` and one `hash` in the file; it matches the generic pattern and not the
    # interpolated current value (whose dots would become regex wildcards).
    sed -i \
      -e "s|^  version = \".*\";$|  version = \"$latest\";|" \
      -e "s|hash = \"sha256-[^\"]*\";|hash = \"$new_hash\";|" \
      "$nix_file"

    echo "curseforge-bump: done. Suggested commit:"
    echo "  git -C \"$repo\" commit -am 'chore(curseforge): $current -> $latest'"
  '';

  meta = {
    description = "Bumps version+hash in pkgs/curseforge.nix to Overwolf's latest release";
    mainProgram = "curseforge-bump";
  };
}
