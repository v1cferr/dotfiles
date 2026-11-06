#!/usr/bin/env bash
# Sets the CurseForge API key end to end: the Bitwarden item, the index line, sync-secrets, then
# the add-on bump and the switch that copies them. docs/notes/apps/wow-addons.md
set -euo pipefail

key="curseforge_api_key"
item="CurseForge API Key" # the name secrets/bitwarden-secrets.json maps the key to
repo="${NH_FLAKE:-$HOME/Projects/GitHub/v1cferr/dotfiles}"
map="$repo/secrets/bitwarden-secrets.json"
cd "$repo"

# Bitwarden: log in and unlock only when needed; the session lives in this process alone.
case "$(bw status | jq -r .status)" in
  unauthenticated) bw login >/dev/null && BW_SESSION="$(bw unlock --raw)" ;;
  locked) BW_SESSION="$(bw unlock --raw)" ;;
esac
export BW_SESSION="${BW_SESSION:-}"
bw sync >/dev/null

# The key is issued on a web page behind a login, the one step no script can take.
echo "Opening console.curseforge.com: sign in, create an API key and copy it."
xdg-open https://console.curseforge.com/ >/dev/null 2>&1 || true

# The key never reaches argv (ps) or the screen: read -s, then jq takes it from env.
read -rsp "Paste the CurseForge API key: " cf_key && echo
if [ -z "$cf_key" ]; then
  echo "Empty key; nothing changed." >&2
  exit 1
fi
export CF_KEY="$cf_key"
unset cf_key

if id="$(bw get item "$item" 2>/dev/null | jq -r .id)" && [ -n "$id" ]; then
  bw get item "$id" | jq '.login.password = env.CF_KEY' | bw encode | bw edit item "$id" >/dev/null
  echo "Updated the Bitwarden item \"$item\"."
else
  bw get template item | jq --arg name "$item" \
    '.type = 1 | .name = $name | .notes = null | .login = { username: null, password: env.CF_KEY, uris: [] }' |
    bw encode | bw create item >/dev/null
  echo "Created the Bitwarden item \"$item\"."
fi
unset CF_KEY

# The index line joins only now: dead-config rejects an entry whose value is not in sops yet.
added=0
if ! jq -e --arg k "$key" 'has($k)' "$map" >/dev/null; then
  jq --arg k "$key" --arg v "$item" '. + {($k): $v}' "$map" >"$map.tmp" && mv "$map.tmp" "$map"
  added=1
fi

# No --yes: if any OTHER secret drifted in Bitwarden, sync-secrets shows it and asks first.
sync-secrets

if [ "$added" -eq 1 ]; then
  git add "$map" secrets/secrets.yaml
  git commit -q -m "feat(wow-addons): index the CurseForge API key" -- "$map" secrets/secrets.yaml
fi

# The bump reads the key from /run/secrets, so it waits for the switch that puts it there.
nh os switch "$repo"
nix run "$repo#vendored-bump" -- "$repo"
nh os switch "$repo"
echo "Done: the add-ons are pinned to their latest stable Forever release and installed."
echo "Commit pkgs/wow-addons/sources.json if the bump moved anything."
