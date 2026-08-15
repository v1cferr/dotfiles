# vscode-bump: it keeps VS Code on the LATEST stable version, with no editing flake.nix by hand.
#
# WHY IT EXISTS: the `vscode-tarball` input (flake.nix) points at a VERSIONED URL on purpose,
# `/1.132.0/linux-x64/stable` and not `/latest/`. The reason is written over there and it is
# structural: `/latest/` is a POINTER, so on every VS Code release the narHash locked in the lock
# file stops matching and the flake no longer evaluates on a clean machine (CI, a fresh clone).
# Which means an "input that updates itself" does not exist with a locked hash; what exists is an
# AUTOMATED BUMP, and this is it. The price of the fixed URL (one manual edit per release) stops
# being paid by a person: what queries the official API and rewrites the number is the script.
#
# WHERE IT RUNS: in the `update`/`upgrade` aliases (home/shell/zsh.nix), BEFORE the `nix flake
# update`. That is why "always latest" works with no `git pull` and no bot committing to the
# branch: the moment the version matters is the rebuild's.
#
# THE TRAPS:
#   • The repo's path comes as an ARGUMENT, never a literal here (rule 11): the SSOT is
#     `programs.nh.flake`, and what reads it is zsh.nix through `osConfig`.
#   • `nix` does NOT go into runtimeInputs on purpose: using the system's (writeShellApplication
#     only PREFIXES the PATH) avoids a second Nix in the store, whose version could diverge from
#     the daemon's.
#   • It leaves the repo DIRTY (flake.nix plus flake.lock modified) and that is intentional: the
#     commit is the user's, atomic, like any bump (rule 13: the lock goes in the same commit as
#     the change that required it).
#   • It is a NO-OP when already on the latest, because it runs on every `upgrade`.
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
