# shellcheck shell=bash
# The idle lock's gate. Only FULLSCREEN VIDEO holds it back: a true fullscreen window whose own
# process owns an MPRIS name in Playing. Audio alone never does, and the hold is capped.
# Policy and history: docs/notes/desktop/lockscreen.md#media-and-the-idle-lock
#
# Inputs come from the environment so the decision can be tested against fixtures:
#   LOCKGATE_MAX_HOLD   seconds the lock may be held in total (set by Nix)
#   LOCKGATE_POLL       seconds between checks (set by Nix)
#   LOCKGATE_FIXTURES   a directory with `fullscreen` and `players` files instead of the live
#                       session; `--decide` then prints hold/lock once and exits (the tests)

# The PIDs of the windows in TRUE fullscreen (state 2). Maximized (1) is not a movie.
fullscreen_pids() {
  if [ -n "${LOCKGATE_FIXTURES:-}" ]; then
    cat "$LOCKGATE_FIXTURES/fullscreen"
    return 0
  fi
  hyprctl -j clients 2>/dev/null | jq -r '.[] | select(.fullscreen == 2) | .pid' 2>/dev/null || true
}

# "<pid> <PlaybackStatus>" for every MPRIS name on the bus. The PID comes from the BUS, not from
# anything the player says about itself, so no player can claim to be another one.
players() {
  if [ -n "${LOCKGATE_FIXTURES:-}" ]; then
    cat "$LOCKGATE_FIXTURES/players"
    return 0
  fi
  local name pid status
  while read -r name; do
    pid=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus \
      GetConnectionUnixProcessID s "$name" 2>/dev/null | cut -d' ' -f2) || continue
    status=$(busctl --user get-property "$name" /org/mpris/MediaPlayer2 \
      org.mpris.MediaPlayer2.Player PlaybackStatus 2>/dev/null | cut -d'"' -f2) || continue
    if [ -n "$pid" ] && [ -n "$status" ]; then printf '%s %s\n' "$pid" "$status"; fi
  done < <(busctl --user list --no-legend 2>/dev/null | cut -d' ' -f1 | grep '^org\.mpris\.MediaPlayer2\.' || true)
}

# Hold when one PID is BOTH a fullscreen window and a Playing player.
video_holds() {
  local fs pid status
  fs=" $(fullscreen_pids | tr '\n' ' ') "
  while read -r pid status; do
    if [ "$status" = Playing ] && [[ "$fs" == *" $pid "* ]]; then return 0; fi
  done < <(players)
  return 1
}

if [ "${1:-}" = --decide ]; then
  if video_holds; then echo hold; else echo lock; fi
  exit 0
fi

max_hold="${LOCKGATE_MAX_HOLD:?}"
poll="${LOCKGATE_POLL:?}"
start=$(date +%s)
if video_holds; then
  # Priority 5 (notice) ONCE, so the journal answers "why did the screen not lock".
  echo "<5>fullscreen video is playing, the idle lock waits for it (at most ${max_hold}s)"
  while video_holds; do
    if [ $(($(date +%s) - start)) -ge "$max_hold" ]; then
      echo "<5>the video hold reached its cap, locking anyway"
      break
    fi
    sleep "$poll"
  done
fi
loginctl lock-session
