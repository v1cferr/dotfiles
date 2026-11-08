#!/usr/bin/env bash
# Seals the phone's enabled third-party apps into secrets/secrets.yaml (sops key android_iac_local):
# versioned and private. The phone is the source, not Bitwarden: docs/notes/hardware/android-iac.md
set -euo pipefail

repo="$(git rev-parse --show-toplevel)"
yaml="$repo/secrets/secrets.yaml"
sealed=/run/secrets/android_iac_local
plain="${XDG_CONFIG_HOME:-$HOME/.config}/android-iac/local.json"

# Read-only on the phone; needs it attached (`adb connect <address>:<port>`).
new="$(android-iac apps | jq -c .)"

# What changes, by name, before anything is written: this is the audit of the sealed list.
old='{"mustBeInstalled":[]}'
if [[ -r $sealed ]]; then
  old="$(jq -c . "$sealed")"
elif [[ -f $plain && ! -L $plain ]]; then
  old="$(jq -c . "$plain")" # the first seal: the list `android-iac apps --save` left
fi
jq -rn --argjson a "$old" --argjson b "$new" '
  ($a.mustBeInstalled // []) as $o | ($b.mustBeInstalled // []) as $n |
  (($n - $o)[] | "+ \(.)"), (($o - $n)[] | "- \(.)"),
  "\($n | length) apps, \(($n - $o) | length) new, \(($o - $n) | length) gone"'

read -r -p "Seal this list into secrets/secrets.yaml? [y/N] " answer
[[ $answer == [yY] ]] || { echo "nothing written"; exit 1; }

# The age key is root's (docs/notes/repo/secrets.md, "Editing by hand"), and sudo drops PATH.
sudo env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt "$(command -v sops)" \
  set "$yaml" '["android_iac_local"]' "$(jq -n --arg v "$new" '$v')"
sudo chown "$(id -un):$(id -gn)" "$yaml"
chmod 644 "$yaml"

# The vault holds it now; a plain copy would block home-manager's link to /run/secrets.
if [[ -f $plain && ! -L $plain ]]; then
  rm "$plain"
fi
echo "sealed. Commit secrets/secrets.yaml, then \`rebuild\`: it links $plain to $sealed"
