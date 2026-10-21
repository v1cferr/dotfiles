# shellcheck shell=bash
# shellcheck disable=SC2016 # the fake locks are single-quoted ON PURPOSE: their $LOCK_SECURE_FILE
# expands in their own shell, where the launcher set it
# The lock's shell logic against fixtures, in a scratch runtime dir: the launcher's choice of
# compositor and its fallback to hyprlock, and the idle gate's decision. No real lock ever starts.
# Run by checks.lockscreen: docs/notes/desktop/lockscreen.md#testing

here=$(cd "$(dirname "$0")" && pwd)
launch="$here/lock-launch.sh"
gate="$here/idle-gate.sh"
fails=0

ok() { printf 'ok   %s\n' "$1"; }
bad() {
  printf 'FAIL %s\n     %s\n' "$1" "$2"
  fails=$((fails + 1))
}
expect() { # name, expected, actual
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2', got '$3'"; fi
}

run=$(mktemp -d)
socks=()
cleanup() {
  for s in "${socks[@]}"; do kill "$s" 2> /dev/null || true; done
  rm -rf "$run"
}
trap cleanup EXIT

# A LIVE Wayland socket in the scratch runtime dir: something listening on it.
live() {
  [ -S "$run/$1" ] && return 0
  socat "UNIX-LISTEN:$run/$1,fork" /dev/null 2> /dev/null &
  socks+=("$!")
  for _ in $(seq 50); do [ -S "$run/$1" ] && return 0; sleep 0.02; done
}

# The launcher's --print against fake instances: "<exit code> <last line of stdout>".
pick() { # instances JSON, WAYLAND_DISPLAY ("-" = unset)
  printf '%s' "$1" > "$run/instances.json"
  local display=(WAYLAND_DISPLAY="$2") out rc=0
  [ "$2" = - ] && display=(-u WAYLAND_DISPLAY)
  out=$(env -u HYPRLAND_INSTANCE_SIGNATURE "${display[@]}" XDG_RUNTIME_DIR="$run" \
    LOCKLAUNCH_INSTANCES="$run/instances.json" bash -euo pipefail "$launch" --print) || rc=$?
  printf '%s %s' "$rc" "$(printf '%s\n' "$out" | tail -n 1)"
}

# ── The compositor: the SESSION's, whatever the environment says (18/10/2026) ──
live wayland-1
expect "a stale display is replaced by the session" "0 wayland-1" \
  "$(pick '[{"instance":"a","time":100,"pid":1,"wl_socket":"wayland-1"}]' wayland-9)"
expect "a missing display is found" "0 wayland-1" \
  "$(pick '[{"instance":"a","time":100,"pid":1,"wl_socket":"wayland-1"}]' -)"
live wayland-3
expect "a nested test compositor never wins" "0 wayland-1" \
  "$(pick '[{"instance":"nested","time":900,"pid":2,"wl_socket":"wayland-3"},{"instance":"session","time":100,"pid":1,"wl_socket":"wayland-1"}]' wayland-3)"
live wayland-2
expect "an instance without a socket is skipped" "0 wayland-2" \
  "$(pick '[{"instance":"dead","time":50,"pid":1,"wl_socket":"wayland-8"},{"instance":"alive","time":100,"pid":2,"wl_socket":"wayland-2"}]' wayland-8)"
live wayland-5
expect "no Hyprland but a live display is kept" "0 wayland-5" "$(pick '[]' wayland-5)"
expect "garbage from hyprctl is survived" "0 wayland-1" "$(pick 'not json' wayland-1)"
expect "nothing alive fails the unit" "1 <3>no live Wayland compositor to lock (WAYLAND_DISPLAY='wayland-9')" \
  "$(pick '[{"instance":"a","time":1,"pid":1,"wl_socket":"wayland-7"}]' wayland-9)"

# ── The fallback: hyprlock locks when the QML lock cannot, or dies locked ──
# A fake QML lock (a shell command) and a fake hyprlock that only leaves a mark.
lockrun() { # the fake QML command; prints "<exit code> <fallback ran: yes|no>"
  rm -f "$run/fallback"
  local rc=0
  env -u HYPRLAND_INSTANCE_SIGNATURE XDG_RUNTIME_DIR="$run" LOCKLAUNCH_INSTANCES="$run/instances.json" \
    WAYLAND_DISPLAY=wayland-1 LOCK_STATE="$run/state" LOCKLAUNCH_WAIT=10 \
    LOCKLAUNCH_QML_CMD="$1" LOCKLAUNCH_FALLBACK_CMD="touch $run/fallback" \
    bash -euo pipefail "$launch" > "$run/launch.log" 2>&1 || rc=$?
  printf '%s %s' "$rc" "$([ -e "$run/fallback" ] && echo yes || echo no)"
}
printf '%s' '[{"instance":"a","time":100,"pid":1,"wl_socket":"wayland-1"}]' > "$run/instances.json"
expect "a lock that unlocks needs no fallback" "0 no" \
  "$(lockrun 'echo secure > "$LOCK_SECURE_FILE"; sleep 0.2; echo unlocked > "$LOCK_SECURE_FILE"')"
expect "a lock that dies locked hands over to hyprlock" "0 yes" \
  "$(lockrun 'echo secure > "$LOCK_SECURE_FILE"; sleep 0.2; exit 139')"
expect "a CLEAN exit without an unlock still hands over" "0 yes" \
  "$(lockrun 'echo secure > "$LOCK_SECURE_FILE"; sleep 0.2; exit 0')"
expect "a lock that never locks is replaced in time" "0 yes" "$(lockrun 'sleep 30')"
expect "a lock that cannot even start is replaced" "0 yes" "$(lockrun 'exit 1')"

# ── The idle gate: only fullscreen video that is PLAYING holds the lock ──
decide() { # fullscreen pids, players ("<pid> <status>" lines)
  mkdir -p "$run/gate"
  printf '%b' "$1" > "$run/gate/fullscreen"
  printf '%b' "$2" > "$run/gate/players"
  LOCKGATE_FIXTURES="$run/gate" bash -euo pipefail "$gate" --decide
}
expect "no players locks" lock "$(decide '' '')"
expect "audio alone locks" lock "$(decide '' '453851 Playing\n')"
expect "paused fullscreen video locks" lock "$(decide '17760\n' '17760 Paused\n')"
expect "fullscreen video playing holds" hold "$(decide '17760\n' '17760 Playing\n')"
expect "a player elsewhere does not borrow a fullscreen window" lock "$(decide '5555\n' '453851 Playing\n')"
expect "the pid match is exact" lock "$(decide '17760\n' '1776 Playing\n')"
expect "one of several holds" hold "$(decide '100\n17760\n' '453851 Playing\n17760 Playing\n')"

if [ "$fails" -gt 0 ]; then
  echo "$fails failed"
  exit 1
fi
echo "all passed"
