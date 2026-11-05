#!/usr/bin/env bash
# cache-push: build what the host needs that no binary cache has, and push it to the R2 cache.
# Why only these and not the whole system: docs/notes/repo/nix-cache.md
#
# Usage: cache-push.sh <flake-attr-of-the-toplevel> <store-url-with-secret-key> [nix args...]
# Exit status: nonzero when any build failed; whatever DID build is pushed anyway.
set -euo pipefail

toplevel="${1:?usage: cache-push.sh <toplevel attr> <store url> [nix args...]}"
store="${2:?usage: cache-push.sh <toplevel attr> <store url> [nix args...]}"
shift 2

# What is missing from every substituter, as `--dry-run` lists it (stderr, human format).
mapfile -t missing < <(
  nix build "$toplevel" "$@" --dry-run 2>&1 |
    sed -n '/will be built:$/,/will be fetched/p' | grep -oE '/nix/store/[^ ]+\.drv'
)
echo "cache-push: ${#missing[@]} derivations missing from every cache"
[ "${#missing[@]}" -eq 0 ] && exit 0

# Only the ones a cache would ever serve. Trivial builders (writeText, buildEnv, units) set
# allowSubstitutes = false, so they always rebuild locally in seconds and caching them is waste.
# Format v4 keeps it under structuredAttrs or env, and jq's `//` would read false as missing.
mapfile -t wanted < <(
  nix derivation show "${missing[@]}" |
    jq -r '.derivations | to_entries[]
      | (.value.structuredAttrs // {}) as $sa
      | select(if $sa | has("allowSubstitutes") then $sa.allowSubstitutes
               else (.value.env.allowSubstitutes // "1") != "" end)
      | "/nix/store/" + .key + "^*"'
)
echo "cache-push: ${#wanted[@]} of them are worth caching"
[ "${#wanted[@]}" -eq 0 ] && exit 0

status=0
nix build --no-link --keep-going "${wanted[@]}" || status=$?

# Push every output that exists now. --no-recursive: their references either come from
# cache.nixos.org or are in this same list, so the closure would only re-upload nixpkgs.
mapfile -t built < <(
  nix derivation show "${wanted[@]%^*}" |
    jq -r '.derivations[].outputs[].path | "/nix/store/" + .' |
    while read -r p; do [ -e "$p" ] && echo "$p"; done
)
echo "cache-push: pushing ${#built[@]} store paths"
[ "${#built[@]}" -gt 0 ] && nix copy --no-recursive --to "$store" "${built[@]}"

exit "$status"
