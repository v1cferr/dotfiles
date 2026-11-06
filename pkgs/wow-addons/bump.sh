#!/usr/bin/env bash
# Moves every entry of sources.json to its latest STABLE WoW Forever release. Runner contract and
# the CurseForge quirks (no search, forbidden distribution): docs/notes/apps/wow-addons.md
set -euo pipefail
shopt -s inherit_errexit

repo="${1:?usage: wow-addons-bump <path-to-the-flake-repo>}"
file="$repo/pkgs/wow-addons/sources.json"
forever=88568 # CurseForge's gameVersionTypeId for "WoW Forever"
cf_api=https://api.curseforge.com/v1
key_file=/run/secrets/curseforge_api_key

tmp=$(mktemp -d)
# An UNREACHABLE upstream keeps the pins and exits 0: it must not take `upgrade` down with it.
on_exit() {
  rc=$?
  if [ "$rc" -ne 0 ] && [ -e "$tmp/unreachable" ]; then
    echo "wow-addons-bump: upstream unreachable, kept the current pins." >&2
    rc=0
  fi
  rm -rf "$tmp"
  exit "$rc"
}
trap on_exit EXIT

curl() {
  local rc=0
  command curl --connect-timeout 5 --max-time 300 "$@" || rc=$?
  case "$rc" in 6 | 7 | 28) touch "$tmp/unreachable" ;; esac
  return "$rc"
}
# --name: an upstream filename may hold `!` or spaces, which a store name rejects.
prefetch() { nix store prefetch-file --json --hash-type sha256 --name addon.zip "$1" | jq -er .hash; }

cf_key=""
[ -r "$key_file" ] && cf_key=$(<"$key_file")

# Prints {"version","url"} of the newest stable Forever file of a CurseForge project. A file the
# author keeps out of the API (downloadUrl null) is still on the public CDN, at a path built from
# its id: the decision to fetch those anyway is in the note.
cf_latest() {
  curl -fsS -H "x-api-key: $cf_key" -H 'Accept: application/json' \
    "$cf_api/mods/$1/files?gameVersionTypeId=$forever&pageSize=50" |
    jq -ce '[.data[] | select(.releaseType == 1)] | sort_by(.fileDate) | last
      | { version: (.id | tostring),
          url: (.downloadUrl // "https://edge.forgecdn.net/files/\(.id / 1000 | floor)/\(.id % 1000)/\(.fileName | @uri)") }'
}

# GitHub allows 60 anonymous API calls an hour, and one tag line costs a call per tag: the gh login,
# when there is one, lifts that to 5000.
gh_token="${GITHUB_TOKEN:-}"
if [ -z "$gh_token" ] && command -v gh >/dev/null; then gh_token=$(gh auth token 2>/dev/null || true); fi
gh_api() {
  if [ -n "$gh_token" ]; then
    curl -fsS -H 'Accept: application/vnd.github+json' -H "Authorization: Bearer $gh_token" "$1"
  else
    curl -fsS -H 'Accept: application/vnd.github+json' "$1"
  fi
}

# Prints {"version","url"} of a GitHub repo's latest release: its zip asset, never release.json.
# With a tag prefix ($2), only that release line counts: spoken-wow ships the add-on and every
# voice pack from one repo, each under its own `<line>/vX` tags.
gh_latest() {
  local api="https://api.github.com/repos/$1" rel tag
  if [ -z "$2" ]; then
    rel=$(gh_api "$api/releases/latest")
  else
    # The TAGS of that line, highest version first: the releases list is paginated and busy
    # (one release per add-on build), so an older pack line falls off its first page.
    rel=""
    while IFS= read -r tag; do
      rel=$(gh_api "$api/releases/tags/$(jq -rn --arg t "$tag" '$t | @uri')") || continue
      jq -e '(.draft | not) and (.prerelease | not)' <<<"$rel" >/dev/null && break
      rel=""
    done < <(gh_api "$api/git/matching-refs/tags/$2" |
      jq -r '.[].ref | sub("^refs/tags/"; "")' | sort -rV)
  fi
  jq -ce '{ version: .tag_name,
    url: ([.assets[] | select(.name | endswith(".zip")) | .browser_download_url] | first) }
    | select(.url != null)' <<<"$rel"
}

new=$(<"$file")
changed=()
for name in $(jq -r 'keys[]' <<<"$new"); do
  entry=$(jq -c --arg n "$name" '.[$n]' <<<"$new")
  case "$(jq -r .source <<<"$entry")" in
    curseforge)
      if [ -z "$cf_key" ]; then
        echo "wow-addons-bump: no CurseForge key at $key_file, kept $name." >&2
        continue
      fi
      latest=$(cf_latest "$(jq -r .projectId <<<"$entry")")
      ;;
    github) latest=$(gh_latest "$(jq -r .repo <<<"$entry")" "$(jq -r '.tagPrefix // ""' <<<"$entry")") ;;
    *)
      echo "wow-addons-bump: $name has an unknown source." >&2
      exit 1
      ;;
  esac

  version=$(jq -r .version <<<"$latest")
  current=$(jq -r .version <<<"$entry")
  [ "$version" = "$current" ] && continue

  url=$(jq -r .url <<<"$latest")
  hash=$(prefetch "$url")
  new=$(jq --arg n "$name" --arg v "$version" --arg u "$url" --arg h "$hash" \
    '.[$n] += { version: $v, url: $u, hash: $h }' <<<"$new")
  changed+=("$name $current -> $version")
done

if [ "${#changed[@]}" -eq 0 ]; then
  echo "wow-addons-bump: every add-on is on its latest stable Forever release."
  exit 0
fi

# Through a temp file, so a failure mid-write never leaves a truncated sources.json behind.
jq . <<<"$new" >"$file.tmp"
mv "$file.tmp" "$file"
printf 'wow-addons-bump: %s\n' "${changed[@]}"
echo "wow-addons-bump: done. Suggested commit:"
echo "  git -C \"$repo\" commit -am 'chore(wow-addons): bump ${#changed[@]} add-on(s)'"
