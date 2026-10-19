# shellcheck shell=bash
# The lock path's only step, ~10 ms: pick the layout and link images that ALREADY exist, never render.
# LOCK_CACHE and LOCK_FALLBACK come from Nix: docs/notes/desktop/lockscreen.md#the-cache

set +e # best effort through and through: a failure here must never cost the lock
cache="$LOCK_CACHE"
fallback="$LOCK_FALLBACK"
session="$cache/session"
mkdir -p "$session"

# Media when something PLAYS as the lock begins, for the whole lock. A `case`, since under pipefail
# an early `grep -q` exit fails the pipe through SIGPIPE.
layout=ambient
case $'\n'"$(timeout 0.5 playerctl --all-players status 2>/dev/null)"$'\n' in
*$'\n'Playing$'\n'*) layout=media ;;
esac

# An image from the ready set if it is there and not empty, the store's fallback otherwise.
resolve() { # $1 = role-layout
  local f="$cache/ready/$1.png"
  if [ -s "$f" ]; then readlink -f "$f"; else printf '%s' "$fallback/$1.png"; fi
}

# Swap a link atomically: a reader (hyprlock on a monitor plugged mid-lock) sees old or new, never none.
put() { # $1 = target, $2 = name in the session
  ln -sfn "$1" "$session/.$2.$$" && mv -Tf "$session/.$2.$$" "$session/$2"
}

put "$(resolve primary-main)" primary
put "$(resolve "secondary-$layout")" secondary
# The quote is COPIED: the set it came from may be collected while this lock still shows it.
q="$cache/ready/quote"
[ -s "$q" ] || q="$fallback/quote"
cp -f "$q" "$session/.quote.$$" && mv -f "$session/.quote.$$" "$session/quote"
printf '%s' "$layout" > "$session/.layout.$$" && mv -f "$session/.layout.$$" "$session/layout"
rm -f "$session/media" # the bridge writes a fresh one; a stale track must not show
exit 0
