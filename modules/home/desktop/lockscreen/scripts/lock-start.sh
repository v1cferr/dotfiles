# shellcheck shell=bash
# The lock path's only preparation, in milliseconds: choose the layout and point the session at
# images that ALREADY exist. Nothing here renders. docs/notes/desktop/lockscreen.md#the-cache
#
# Environment (set by Nix): LOCK_CACHE (…/lockscreen/v2), LOCK_FALLBACK (the build-time images).

set +e # best effort through and through: a failure here must never cost the lock
cache="$LOCK_CACHE"
fallback="$LOCK_FALLBACK"
session="$cache/session"
mkdir -p "$session"

# Media when something is PLAYING as the lock begins; it stays for the whole lock session, since
# switching would mean reloading the background.
# A `case` and not `| grep -q`: under pipefail an early grep exit fails the pipe through SIGPIPE.
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
