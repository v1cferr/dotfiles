# vscode-bump: rewrites the vscode-tarball version in flake.nix to the latest stable.
# Why a versioned URL needs a bump script at all: docs/notes/repo/version-bumps.md
{
  writeShellApplication,
  curl,
  jq,
  gnused,
}:

writeShellApplication {
  name = "vscode-bump";
  runtimeInputs = [
    curl
    jq
    gnused
  ];

  # set -euo pipefail already comes from writeShellApplication (the default bashOptions).
  text = ''
    repo="''${1:?usage: vscode-bump <path-to-the-flake-repo>}"
    nix_file="$repo/flake.nix"

    # The version LOCKED today: read from flake.nix itself, which is the SSOT of the VS Code
    # version.
    current=$(sed -n \
      's|.*update\.code\.visualstudio\.com/\([0-9][0-9.]*\)/linux-x64/stable.*|\1|p' \
      "$nix_file")
    if [ -z "$current" ]; then
      echo "vscode-bump: could not find the vscode-tarball versioned URL in $nix_file" >&2
      echo "             (did the input change shape? check flake.nix)" >&2
      exit 1
    fi

    # The version SERVED right now by the stable channel. `productVersion` and not `version`: the
    # second is the commit hash ("df53daa…"), not the 1.132.0 that goes in the URL.
    latest=$(curl -fsSL \
      https://update.code.visualstudio.com/api/update/linux-x64/stable/latest |
      jq -r '.productVersion')
    case "$latest" in
      *[!0-9.]* | "")
        echo "vscode-bump: the API returned an implausible version: '$latest'" >&2
        exit 1
        ;;
    esac

    if [ "$current" = "$latest" ]; then
      echo "vscode-bump: already on the latest ($current)."
      exit 0
    fi

    echo "vscode-bump: $current -> $latest"
    # It rewrites only the number, matching the generic pattern (and not the interpolated
    # "$current", whose dots would become regex wildcards).
    sed -i \
      "s|\(update\.code\.visualstudio\.com/\)[0-9.]*\(/linux-x64/stable\)|\1$latest\2|" \
      "$nix_file"

    # Without this, flake.nix and the lock would disagree until the next evaluation: it is this
    # command that downloads the new tarball and records its narHash.
    nix flake update vscode-tarball --flake "$repo"

    echo "vscode-bump: done. Suggested commit:"
    echo "  git -C \"$repo\" commit -am 'chore(vscode): $current -> $latest'"
  '';

  meta = {
    description = "Bumps the vscode-tarball input to VS Code's latest stable version";
    mainProgram = "vscode-bump";
  };
}
