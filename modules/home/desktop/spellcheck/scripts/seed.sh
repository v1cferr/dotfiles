# shellcheck shell=bash
# spellcheck-seed: writes the SSOT languages into each Electron app's Chromium `Preferences`
# (spellcheck.dictionaries), for apps with no language setting of their own. The app downloads the
# .bdic itself. Skips a running app: it would rewrite the file on exit. Why: docs/notes/desktop/spellcheck.md
# SPELLCHECK_LANGUAGES (one BCP 47 tag per line) and SPELLCHECK_PROFILES (one Preferences path per
# line, relative to $XDG_CONFIG_HOME) come from runtimeEnv (default.nix).
set -euo pipefail

config="${XDG_CONFIG_HOME:-$HOME/.config}"
langs="$(jq -Rnc '[inputs]' <<<"$SPELLCHECK_LANGUAGES")"

# Chromium's SingletonLock points at "<host>-<pid>" and outlives a clean exit, so the pid decides.
running() {
  local lock pid
  lock="$(readlink "$1/SingletonLock" 2>/dev/null)" || return 1
  pid="${lock##*-}"
  kill -0 "$pid" 2>/dev/null
}

while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  prefs="$config/$rel"
  [ -f "$prefs" ] || continue # never opened yet: Chromium creates it, the next switch seeds it
  if jq -e --argjson l "$langs" '.spellcheck.dictionaries == $l' "$prefs" >/dev/null; then
    continue
  fi
  # The lock sits in the userData dir: the file's dir or, for a Default/ profile, its parent.
  dir="$(dirname "$prefs")"
  if running "$dir" || running "$(dirname "$dir")"; then
    echo "spellcheck-seed: $rel skipped, the app is running"
    continue
  fi
  tmp="$(mktemp "$prefs.XXXXXX")"
  jq -c --argjson l "$langs" '.spellcheck.dictionaries = $l' "$prefs" >"$tmp"
  mv "$tmp" "$prefs"
  echo "spellcheck-seed: $rel now checks $langs"
done <<<"$SPELLCHECK_PROFILES"
