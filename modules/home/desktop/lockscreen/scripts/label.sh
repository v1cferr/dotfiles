# shellcheck shell=bash
# What hyprlock's labels print, from files others wrote; builtins only, since they run while locked.
# LOCK_* come from Nix: docs/notes/desktop/lockscreen.md#what-the-lock-runs-and-what-it-costs-per-tick

session="$LOCK_CACHE/session"

# A file's whole content into $REPLY, or empty when it is missing.
slurp() {
  REPLY=""
  if [ -r "$1" ]; then IFS= read -r -d "" REPLY < "$1" || true; fi # EOF is read's 1, not an error
}

# Print $1 without its trailing newlines: a here-string adds one of its own, so one strip is not enough.
out() {
  local m="$1"
  while [[ $m == *$'\n' ]]; do m="${m%$'\n'}"; done
  printf '%s' "$m"
}

case "${1:-}" in
date)
  export LC_TIME=pt_BR.UTF-8
  printf -v d '%(%A  ·  %d de %B  ·  semana %V)T' -1
  printf '<span letter_spacing="1024">%s</span>' "${d^}"
  ;;
weather)
  # Line 1: valid until (epoch); line 2: when the forecast was fetched; then the markup.
  slurp "$LOCK_CACHE/weather"
  valid="" fetched="" markup=""
  { read -r valid; read -r fetched; IFS= read -r -d "" markup; } <<< "$REPLY" || true
  if [[ $valid =~ ^[0-9]+$ && $fetched =~ ^[0-9]+$ ]] &&
    ((EPOCHSECONDS < valid && EPOCHSECONDS - fetched < LOCK_WEATHER_MAX_AGE)); then
    out "$markup"
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
    out "$markup"
  else
    printf '<span foreground="#%s">%s</span>' "$LOCK_COL_SUBTEXT" "$LOCK_TXT_NO_MEDIA"
  fi
  ;;
mediacap)
  # $2, the media section's caption, only in the layout that has the section.
  slurp "$session/layout"
  [ "$REPLY" = media ] || exit 0
  printf '%s' "${2:?}"
  ;;
obs)
  # The observe service's cards: `pid`, `epoch`, markup. Shown only from a LIVE writer and while
  # fresh, so a card never presents an old number as now.
  slurp "$session/obs/${2:?}"
  pid="" at="" markup=""
  { read -r pid; read -r at; IFS= read -r -d "" markup; } <<< "$REPLY" || true
  if [[ $pid =~ ^[0-9]+$ && $at =~ ^[0-9]+$ ]] && kill -0 "$pid" 2> /dev/null &&
    ((EPOCHSECONDS - at < LOCK_OBS_MAX_AGE)); then
    out "$markup"
  else
    printf '<span foreground="#%s">%s</span>' "$LOCK_COL_SUBTEXT" "$LOCK_TXT_NO_DATA"
  fi
  ;;
quote)
  slurp "$session/quote"
  out "$REPLY"
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
  echo "usage: lockscreen-label date|weather|media|mediacap <caption>|obs <card>|quote|hint" >&2
  exit 2
  ;;
esac
