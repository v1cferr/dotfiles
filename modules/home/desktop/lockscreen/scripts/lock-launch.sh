# shellcheck shell=bash
# The lock's launcher: lock the SESSION's (oldest) Hyprland even if the manager's WAYLAND_DISPLAY went
# stale, with the QML lock, and hand over to hyprlock when it does not lock or dies locked.
# --print, LOCKLAUNCH_INSTANCES, LOCKLAUNCH_QML_CMD and LOCKLAUNCH_FALLBACK_CMD are for the tests:
# docs/notes/desktop/lockscreen.md#when-the-lock-cannot-reach-the-compositor

runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
wanted="${WAYLAND_DISPLAY:-}"

instances() {
  if [ -n "${LOCKLAUNCH_INSTANCES:-}" ]; then cat "$LOCKLAUNCH_INSTANCES"; else hyprctl instances -j 2> /dev/null; fi
}

# "<socket> <signature>" of the OLDEST instance whose socket really exists: a nested test is younger.
read -r sock sig <<< "$(instances | jq -r '
  [.[] | select(.wl_socket != null)] | sort_by(.time) | .[] | "\(.wl_socket) \(.instance)"' 2> /dev/null |
  while read -r s i; do
    if [ -S "$runtime/$s" ]; then
      printf '%s %s\n' "$s" "$i"
      break
    fi
  done)" || true

if [ -n "${sock:-}" ]; then
  if [ "$wanted" != "$sock" ]; then
    # Priority 4 (warning): the journal says the environment was wrong, and what was locked instead.
    echo "<4>WAYLAND_DISPLAY='$wanted' is not the session's compositor; locking $sock instead"
  fi
  export WAYLAND_DISPLAY="$sock" HYPRLAND_INSTANCE_SIGNATURE="$sig"
elif [ -n "$wanted" ] && [ -S "$runtime/$wanted" ]; then
  : # no Hyprland listed, but the given display is alive: keep it
else
  echo "<3>no live Wayland compositor to lock (WAYLAND_DISPLAY='$wanted')"
  exit 1 # fails the unit, and OnFailure pushes the alarm to the phone
fi

if [ "${1:-}" = --print ]; then
  printf '%s\n' "$WAYLAND_DISPLAY"
  exit 0
fi

# hyprlock, the fallback: with allow_session_lock_restore it also takes over a lock whose client died.
fallback() {
  if [ -n "${LOCKLAUNCH_FALLBACK_CMD:-}" ]; then exec sh -c "$LOCKLAUNCH_FALLBACK_CMD"; fi
  exec hyprlock
}

# The QML lock writes "secure" here once every output is covered, and "unlocked" after PAM says yes.
export LOCK_SECURE_FILE="$runtime/lockscreen/secure"
mkdir -p "${LOCK_SECURE_FILE%/*}" "${LOCK_STATE:?}"
rm -f "$LOCK_SECURE_FILE"
if [ -n "${LOCKLAUNCH_QML_CMD:-}" ]; then
  sh -c "$LOCKLAUNCH_QML_CMD" &
else
  qs -p "${LOCK_QML:?}" &
fi
qml=$!

# No file in time means no lock: kill it and let hyprlock lock instead.
wait_max="${LOCKLAUNCH_WAIT:-50}" # tenths of a second
waited=0
while [ ! -e "$LOCK_SECURE_FILE" ] && kill -0 "$qml" 2> /dev/null && [ "$waited" -lt "$wait_max" ]; do
  sleep 0.1
  waited=$((waited + 1))
done
if [ ! -e "$LOCK_SECURE_FILE" ]; then
  echo "<3>the QML lock did not lock within $((wait_max / 10)) s; hyprlock locks instead"
  kill "$qml" 2> /dev/null || true
  wait "$qml" 2> /dev/null || true
  fallback
fi

# Locked. Only a PAM success writes "unlocked"; an exit without it (a crash, a signal, even a clean
# exit by mistake) left the screen locked with no client, so hyprlock reattaches.
rc=0
wait "$qml" || rc=$?
if [ "$(cat "$LOCK_SECURE_FILE" 2> /dev/null)" != unlocked ]; then
  echo "<3>the QML lock exited ($rc) without an unlock; hyprlock takes the session over"
  fallback
fi
rm -f "$LOCK_SECURE_FILE"
