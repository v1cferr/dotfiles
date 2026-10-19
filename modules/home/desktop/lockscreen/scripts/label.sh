# shellcheck shell=bash
# What hyprlock's labels print, from files other processes wrote. Builtins only, since a label runs
# every few seconds while locked: no date, no cat, no stat. docs/notes/desktop/lockscreen.md#the-labels
#
# Environment (set by Nix): LOCK_CACHE, LOCK_PRIMARY (the main connector), and the LOCK_TXT_*
# strings below; colors as LOCK_COL_* hexes without '#'.

session="$LOCK_CACHE/session"

# A file's whole content into $REPLY, or empty when it is missing.
slurp() {
  REPLY=""
  if [ -r "$1" ]; then IFS= read -r -d "" REPLY < "$1" || true; fi # EOF is read's 1, not an error
}

case "${1:-}" in
clock)
  # Within 10 ms of the next second, wait for it: the 1000.5 ms timer would otherwise skip a
  # second every ~33 min as its phase wraps (measured in the notes). External sleep, only then.
  us=${EPOCHREALTIME#*.}
  if ((10#$us > 990000)); then
    printf -v wait '0.%06d' $((1002000 - 10#$us))
    sleep "$wait"
  fi
  printf '%(%H:%M:%S)T' -1
  ;;
date)
  export LC_TIME=pt_BR.UTF-8
  printf -v d '%(%A, %d de %B de %Y  ·  Semana %V)T' -1
  printf '%s' "${d^}"
  ;;
weather)
  # Line 1: valid until (epoch); line 2: when the forecast was fetched; then the markup.
  slurp "$LOCK_CACHE/weather"
  valid="" fetched="" markup=""
  { read -r valid; read -r fetched; IFS= read -r -d "" markup; } <<< "$REPLY" || true
  if [[ $valid =~ ^[0-9]+$ && $fetched =~ ^[0-9]+$ ]] &&
    ((EPOCHSECONDS < valid && EPOCHSECONDS - fetched < LOCK_WEATHER_MAX_AGE)); then
    printf '%s' "${markup%$'\n'}"
  else
    printf '<span foreground="#%s">%s</span>' "$LOCK_COL_SUBTEXT" "$LOCK_TXT_NO_WEATHER"
  fi
  ;;
media)
  slurp "$session/layout"
  [ "$REPLY" = media ] || exit 0 # the Ambient layout has no media card: print nothing
  slurp "$session/media"
  pid="" markup=""
  { read -r pid; IFS= read -r -d "" markup; } <<< "$REPLY" || true
  # The bridge's PID heads the file: a dead bridge means the text may be stale, so it is not shown.
  if [[ $pid =~ ^[0-9]+$ ]] && kill -0 "$pid" 2> /dev/null; then
    printf '%s' "${markup%$'\n'}"
  else
    printf '<span foreground="#%s">%s</span>' "$LOCK_COL_SUBTEXT" "$LOCK_TXT_NO_MEDIA"
  fi
  ;;
quote)
  slurp "$session/quote"
  printf '%s' "${REPLY%$'\n'}"
  ;;
hint)
  # Empty while the main monitor is connected; otherwise, wherever the lock still draws, how to
  # unlock without seeing a password field (hyprlock's password buffer is global).
  for f in /sys/class/drm/card*-"$LOCK_PRIMARY"/status; do
    st=""
    if [ -r "$f" ]; then read -r st < "$f" || true; fi
    [ "$st" = connected ] && exit 0
  done
  printf '<span background="#%s" bgalpha="85%%" foreground="#%s"> %s </span>' \
    "$LOCK_COL_BG" "$LOCK_COL_TEXT" "$LOCK_TXT_HINT"
  ;;
*)
  echo "usage: lockscreen-label clock|date|weather|media|quote|hint" >&2
  exit 2
  ;;
esac
