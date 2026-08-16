# curseforge-bump: rewrites version AND hash in pkgs/curseforge.nix to Overwolf's latest.
# Why the .deb answers "did it change?" for 256 KiB: docs/notes/repo/version-bumps.md
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

    # ONLY the start of the .deb: `control` sits before the `data.tar.*` bulk.
    curl -fsSL -r 0-262143 -o "$tmp/head.deb" "$base/curseforge-latest-linux.deb"
    member=$(ar t "$tmp/head.deb" | sed -n '/^control\.tar/p' | head -1)
    if [ -z "$member" ]; then
      echo "curseforge-bump: the .deb has no control.tar* in the first 256 KiB" >&2
      exit 1
    fi
    # A FILE and not a pipe: GNU tar only autodetects the compression when it can seek.
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

    # The generic pattern, not the interpolated value (whose dots are regex wildcards).
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
