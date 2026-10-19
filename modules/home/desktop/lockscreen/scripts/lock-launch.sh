# shellcheck shell=bash
# hyprlock's launcher: lock the SESSION's (oldest) Hyprland even if the manager's WAYLAND_DISPLAY went
# stale. --print and LOCKLAUNCH_INSTANCES are for the tests: docs/notes/desktop/lockscreen.md#when-the-lock-cannot-reach-the-compositor

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
exec hyprlock "$@"
