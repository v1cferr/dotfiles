# mkVendoredBump: the ONE skeleton every vendored bump follows; a package only answers two questions.
# The pkgs/<name>/{package.nix,source.json,bump.nix} contract: docs/notes/repo/version-bumps.md
{
  writeShellApplication,
  curl,
  jq,
}:

{
  pname, # names the bump and locates pkgs/<pname>/source.json
  latest, # shell that PRINTS upstream's latest version, as cheaply as upstream allows; $tmp is scratch
  resolve, # shell that, with $version set, PRINTS {"url": ..., "hash": ...} for that release
  runtimeInputs ? [ ],
}:

writeShellApplication {
  name = "${pname}-bump";
  runtimeInputs = [
    curl
    jq
  ]
  ++ runtimeInputs;

  # set -euo pipefail comes from writeShellApplication; inherit_errexit makes it reach into $(...).
  text = ''
    shopt -s inherit_errexit
    repo="''${1:?usage: ${pname}-bump <path-to-the-flake-repo>}"
    file="$repo/pkgs/${pname}/source.json"
    current=$(jq -er .version "$file")

    # A scratch dir for `latest`/`resolve`, cleaned on ANY exit so a package never has to.
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    # Two helpers for `resolve`: hash by downloading, or convert the hash upstream PUBLISHES.
    prefetch() { nix store prefetch-file --json --hash-type sha256 "$1" | jq -er .hash; }
    sri() { nix hash convert --hash-algo "$1" --from base16 --to sri "$2"; }

    latest() {
      ${latest}
    }
    resolve() {
      ${resolve}
    }

    version=$(latest)
    # An endpoint that starts answering HTML or an error page is what this catches.
    case "$version" in
      *[!0-9.-]* | "")
        echo "${pname}-bump: upstream answered an implausible version: '$version'" >&2
        exit 1
        ;;
    esac

    if [ "$current" = "$version" ]; then
      echo "${pname}-bump: already on the latest ($current)."
      exit 0
    fi

    echo "${pname}-bump: $current -> $version"
    src=$(resolve)
    if ! jq -e '(.url | type == "string") and (.hash | test("^sha(256|512)-"))' \
      <<<"$src" >/dev/null; then
      echo "${pname}-bump: resolve gave no url plus SRI hash: $src" >&2
      exit 1
    fi

    # Through a temp file, so a failure mid-write never leaves a truncated source.json behind.
    jq --arg version "$version" '{ version: $version, url, hash }' <<<"$src" >"$file.tmp"
    mv "$file.tmp" "$file"

    echo "${pname}-bump: done. Suggested commit:"
    echo "  git -C \"$repo\" commit -am 'chore(${pname}): $current -> $version'"
  '';

  meta = {
    description = "Bumps pkgs/${pname}/source.json to upstream's latest release";
    mainProgram = "${pname}-bump";
  };
}
