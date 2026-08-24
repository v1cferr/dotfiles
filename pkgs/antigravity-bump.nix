# antigravity-bump: rewrites version, build id AND hash in pkgs/antigravity-cli.nix to Google's
# latest. Why the hash costs no download here: docs/notes/repo/version-bumps.md
{
  writeShellApplication,
  curl,
  gnused,
  jq,
}:

writeShellApplication {
  name = "antigravity-bump";
  runtimeInputs = [
    curl
    gnused
    jq # the manifest is JSON, and both the url and the hash come out of it
  ];

  # set -euo pipefail already comes from writeShellApplication (the default bashOptions).
  text = ''
    repo="''${1:?usage: antigravity-bump <path-to-the-flake-repo>}"
    nix_file="$repo/pkgs/antigravity-cli.nix"
    base="https://storage.googleapis.com/antigravity-public/antigravity-cli"

    # The version LOCKED today: pkgs/antigravity-cli.nix is its SSOT.
    current=$(sed -n 's|^  version = "\(.*\)";$|\1|p' "$nix_file")
    if [ -z "$current" ]; then
      echo "antigravity-bump: could not find the \`version\` in $nix_file" >&2
      echo "                  (did the package change shape? check pkgs/antigravity-cli.nix)" >&2
      exit 1
    fi

    # "Did it change?" costs 7 bytes: `latest` is a plain text file holding the version.
    latest=$(curl -fsSL "$base/latest")
    # A pointer that starts answering HTML or an error page is what this catches.
    case "$latest" in
      *[!0-9.]* | "")
        echo "antigravity-bump: '$latest' does not look like a version" >&2
        exit 1
        ;;
    esac

    if [ "$current" = "$latest" ]; then
      echo "antigravity-bump: already on the latest ($current)."
      exit 0
    fi

    # The manifest carries the URL (with the opaque build id) and the sha512 of every platform.
    manifest=$(curl -fsSL "$base/$latest/manifest.json")
    url=$(printf '%s' "$manifest" | jq -er '.platforms."linux-x64".url')
    sha512=$(printf '%s' "$manifest" | jq -er '.platforms."linux-x64".sha512')

    # `<version>-<build id>` is the first path segment after the base, and only the id is wanted.
    whole=''${url#"$base/"}
    build_id=''${whole%%/*}
    build_id=''${build_id#*-}
    case "$build_id" in
      *[!0-9]* | "")
        echo "antigravity-bump: '$url' has no <version>-<build id> segment" >&2
        exit 1
        ;;
    esac

    # THE POINT of using the published hash: fetchurl takes SRI, the manifest speaks base16, and
    # the conversion is arithmetic. No 56 MiB download just to learn a number they already state.
    new_hash=$(nix hash convert --hash-algo sha512 --from base16 --to sri "$sha512")

    echo "antigravity-bump: $current -> $latest (build $build_id)"

    # The generic pattern, not the interpolated value (whose dots are regex wildcards).
    sed -i \
      -e "s|^  version = \".*\";$|  version = \"$latest\";|" \
      -e "s|^  buildId = \".*\";$|  buildId = \"$build_id\";|" \
      -e "s|hash = \"sha512-[^\"]*\";|hash = \"$new_hash\";|" \
      "$nix_file"

    echo "antigravity-bump: done. Suggested commit:"
    echo "  git -C \"$repo\" commit -am 'chore(antigravity): $current -> $latest'"
  '';

  meta = {
    description = "Bumps version+build id+hash in pkgs/antigravity-cli.nix to Google's latest";
    mainProgram = "antigravity-bump";
  };
}
