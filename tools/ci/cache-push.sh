#!/usr/bin/env bash
# cache-push: build what the host needs that no binary cache has, and push it to the R2 cache.
# Why only these and not the whole system: docs/notes/repo/nix-cache.md
#
# Usage: cache-push.sh <flake-attr-of-the-toplevel> <signing-key-file> [nix args...]
# Reads the bucket from modules/nixos/core/nix-cache/cache.json; the R2 credentials come from the
# AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY environment, for both nix and the aws CLI.
# Exit status: nonzero when any build failed; whatever DID build is pushed anyway.
set -euo pipefail

toplevel="${1:?usage: cache-push.sh <toplevel attr> <signing key file> [nix args...]}"
key="${2:?usage: cache-push.sh <toplevel attr> <signing key file> [nix args...]}"
shift 2

cfg=modules/nixos/core/nix-cache/cache.json
bucket=$(jq -er .bucket "$cfg")
endpoint="https://$(jq -er .account "$cfg").r2.cloudflarestorage.com"
# R2 rejects the CRC checksums newer aws CLIs send by default; region "auto" is R2's only one.
export AWS_DEFAULT_REGION=auto AWS_REQUEST_CHECKSUM_CALCULATION=WHEN_REQUIRED AWS_RESPONSE_CHECKSUM_VALIDATION=WHEN_REQUIRED
r2() { aws s3 --endpoint-url "$endpoint" --only-show-errors "$@"; }

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

# Every output that exists now. The store resolves them: `derivation show` leaves `path` out of
# fixed-output ones.
mapfile -t push < <(
  nix-store --query --outputs "${wanted[@]%^*}" |
    while read -r p; do [ -e "$p" ] && echo "$p"; done
)
[ "${#push[@]}" -eq 0 ] && exit "$status"

# A binary cache refuses a path whose references it does not hold, and copying whole closures
# would re-upload nixpkgs into a 10 GB free tier. So the copy goes into a local STAGING cache
# where each outside reference is only its real narinfo, fetched from cache.nixos.org or from
# R2; just the pushed paths' files go up. A reference neither has (a trivial builder's output)
# joins the push, and its own references get the same treatment.
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
declare -A pushing=()
for p in "${push[@]}"; do pushing[$p]=1; done
pending=("${push[@]}")
stubs=()
while [ "${#pending[@]}" -gt 0 ]; do
  mapfile -t refs < <(nix-store --query --references "${pending[@]}" | sort -u)
  pending=()
  for r in "${refs[@]}"; do
    [ -n "${pushing[$r]:-}" ] && continue
    pushing[$r]=1 # visited, whichever way it resolves
    h=$(basename "$r" | cut -d- -f1)
    if curl -fsS --retry 3 -o "$staging/$h.narinfo" "https://cache.nixos.org/$h.narinfo" 2>/dev/null ||
      r2 cp "s3://$bucket/$h.narinfo" "$staging/$h.narinfo" 2>/dev/null; then
      stubs+=("$staging/$h.narinfo")
    else
      push+=("$r")
      pending+=("$r")
    fi
  done
done
echo "cache-push: pushing ${#push[@]} store paths (${#stubs[@]} references resolved elsewhere)"

nix copy --no-recursive --to "file://$staging?compression=zstd&parallel-compression=true&secret-key=$key" "${push[@]}"
rm -f "${stubs[@]}"
r2 cp --recursive "$staging" "s3://$bucket"

exit "$status"
