# codex-bump: rewrites version AND hash in pkgs/codex.nix to OpenAI's latest release.
# Why the redirect answers "did it change?" for free: docs/notes/repo/version-bumps.md
{
  writeShellApplication,
  curl,
  gnused,
}:

writeShellApplication {
  name = "codex-bump";
  runtimeInputs = [
    curl
    gnused
  ];

  # set -euo pipefail already comes from writeShellApplication (the default bashOptions).
  text = ''
    repo="''${1:?usage: codex-bump <path-to-the-flake-repo>}"
    nix_file="$repo/pkgs/codex.nix"
    project="https://github.com/openai/codex"

    # The version LOCKED today: pkgs/codex.nix is its SSOT.
    current=$(sed -n 's|^  version = "\(.*\)";$|\1|p' "$nix_file")
    if [ -z "$current" ]; then
      echo "codex-bump: could not find the \`version\` in $nix_file" >&2
      echo "            (did the package change shape? check pkgs/codex.nix)" >&2
      exit 1
    fi

    # /releases/latest REDIRECTS to the tag, so the question costs one HEAD with no token: the
    # API would answer the same and spend one of the 60 anonymous calls per hour.
    tag=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$project/releases/latest")
    latest=''${tag##*/rust-v}
    # A tag that does not match `rust-v<semver>` leaves the URL itself in `latest`, and the
    # slashes and letters are what this catches. Prereleases never get here: /latest skips them.
    case "$latest" in
      *[!0-9.]* | "")
        echo "codex-bump: '$tag' does not look like a rust-v<version> tag" >&2
        exit 1
        ;;
    esac

    if [ "$current" = "$latest" ]; then
      echo "codex-bump: already on the latest ($current)."
      exit 0
    fi

    echo "codex-bump: $current -> $latest (downloading the tarball for the hash...)"
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL -o "$tmp/codex.tar.gz" \
      "$project/releases/download/rust-v$latest/codex-package-x86_64-unknown-linux-musl.tar.gz"
    new_hash=$(nix hash file --type sha256 --sri "$tmp/codex.tar.gz")

    # The generic pattern, not the interpolated value (whose dots are regex wildcards).
    sed -i \
      -e "s|^  version = \".*\";$|  version = \"$latest\";|" \
      -e "s|hash = \"sha256-[^\"]*\";|hash = \"$new_hash\";|" \
      "$nix_file"

    echo "codex-bump: done. Suggested commit:"
    echo "  git -C \"$repo\" commit -am 'chore(codex): $current -> $latest'"
  '';

  meta = {
    description = "Bumps version+hash in pkgs/codex.nix to OpenAI's latest codex release";
    mainProgram = "codex-bump";
  };
}
