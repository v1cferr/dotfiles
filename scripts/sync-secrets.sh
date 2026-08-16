#!/usr/bin/env bash
# It syncs the secrets from Bitwarden into secrets/secrets.yaml (sops), with no --impure.
# Adding one: Bitwarden, then 1 line in bitwarden-secrets.json, then this: docs/notes/secrets.md
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
map="$repo/secrets/bitwarden-secrets.json"
yaml="$repo/secrets/secrets.yaml"

if ! bw status | jq -e '.status == "unlocked"' >/dev/null 2>&1; then
  echo "Bitwarden is locked or logged out. Run:" >&2
  echo "  bw login                            # if you have not logged in yet" >&2
  echo "  export BW_SESSION=\$(bw unlock --raw)" >&2
  exit 1
fi

# The age key (root's) is read ONLY into the process' memory, it does not go to disk.
SOPS_AGE_KEY="$(sudo cat /var/lib/sops-nix/key.txt)"
export SOPS_AGE_KEY

n=0
while IFS=$'\t' read -r key spec; do
  [ -z "$key" ] && continue
  # spec = "Item" (the default field: password) OR "Item:field" ("duolingo.com:username", say)
  item="${spec%%:*}"
  field="password"
  case "$spec" in *:*) field="${spec##*:}" ;; esac
  val="$(bw get "$field" "$item")"
  sops set "$yaml" "[\"$key\"]" "\"$val\""
  echo "  ok  $key  <-  Bitwarden: \"$item\" ($field)"
  n=$((n + 1))
done < <(jq -r 'to_entries[] | "\(.key)\t\(.value)"' "$map")

git -C "$repo" add secrets/secrets.yaml secrets/bitwarden-secrets.json
echo ""
echo "$n secret(s) synced. Apply them with:"
# $HOSTNAME is a BUILTIN, so it does not depend on the PATH (writeShellApplication's
# runtimeInputs is strict). It used to name a host that died in the cutover.
echo "  sudo nixos-rebuild switch --flake .#$HOSTNAME"
