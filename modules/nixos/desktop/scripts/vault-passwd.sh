#!/usr/bin/env bash
# Sets (or changes) the app vault's own password, end to end: the Bitwarden item, then
# sync-secrets into sops, then the switch that puts it in /run/secrets. docs/notes/desktop/vault.md
set -euo pipefail

item="App Vault Password" # the name secrets/bitwarden-secrets.json maps to vault_password
repo="${NH_FLAKE:-$HOME/Projects/GitHub/v1cferr/dotfiles}"
cd "$repo"

# Bitwarden: log in and unlock only when needed; the session lives in this process alone.
case "$(bw status | jq -r .status)" in
  unauthenticated) bw login >/dev/null && BW_SESSION="$(bw unlock --raw)" ;;
  locked) BW_SESSION="$(bw unlock --raw)" ;;
esac
export BW_SESSION="${BW_SESSION:-}"
bw sync >/dev/null

# The password never reaches argv (ps) or the screen: read -s, then jq takes it from env.
read -rsp "New app vault password: " pw1 && echo
read -rsp "Again: " pw2 && echo
if [ -z "$pw1" ] || [ "$pw1" != "$pw2" ]; then
  echo "Empty or not the same twice; nothing changed." >&2
  exit 1
fi
export VAULT_PW="$pw1"
unset pw1 pw2

if id="$(bw get item "$item" 2>/dev/null | jq -r .id)" && [ -n "$id" ]; then
  bw get item "$id" | jq '.login.password = env.VAULT_PW' | bw encode | bw edit item "$id" >/dev/null
  echo "Updated the Bitwarden item \"$item\"."
else
  bw get template item | jq --arg name "$item" \
    '.type = 1 | .name = $name | .notes = null | .login = { username: null, password: env.VAULT_PW, uris: [] }' |
    bw encode | bw create item >/dev/null
  echo "Created the Bitwarden item \"$item\"."
fi
unset VAULT_PW

# No --yes: if any OTHER secret drifted in Bitwarden, sync-secrets shows it and asks first.
sync-secrets
nh os switch "$repo"
hyprctl -i 0 reload >/dev/null || true
echo "Done: the vault now asks for the new password."
