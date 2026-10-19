# shellcheck shell=bash
# The media card's text, rewritten on every MPRIS change while the screen is locked, never polled.
# Lives only inside a Media lock (BindsTo hyprlock.service). docs/notes/desktop/lockscreen.md#media
#
# Environment (set by Nix): LOCK_CACHE, LOCK_TITLE_COLS, LOCK_ARTIST_COLS, LOCK_COL_SUBTEXT,
# LOCK_TXT_NO_MEDIA. Needs a UTF-8 locale, so ${#s} counts characters.

out="$LOCK_CACHE/session/media"
sep=$'\x1f' # a unit separator: no sane title holds one, unlike a tab
# bash 5.2 expands `&` in a ${s//x/y} replacement to the match, which breaks the escaping below.
shopt -u patsub_replacement

# Monospace columns of one character into $W: East Asian wide, full width and emoji take two.
width_of() { # $1 = one character
  local cp
  W=1
  printf -v cp '%d' "'$1"
  if ((cp >= 0x1100 && cp <= 0x115F || cp >= 0x2E80 && cp <= 0xA4CF || cp >= 0xAC00 && cp <= 0xD7A3 ||
    cp >= 0xF900 && cp <= 0xFAFF || cp >= 0xFE30 && cp <= 0xFE4F || cp >= 0xFF00 && cp <= 0xFF60 ||
    cp >= 0xFFE0 && cp <= 0xFFE6 || cp >= 0x1F300 && cp <= 0x1FAFF || cp >= 0x20000 && cp <= 0x3FFFD)); then
    W=2
  fi
}

# Clean, cut to $2 columns with an ellipsis, then escape for pango. Cut BEFORE escaping, so an
# entity is never split.
fit() { # $1 = text, $2 = columns; prints the markup-safe result
  local s="${1//[[:cntrl:]]/}" res="" used=0 i c
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    width_of "$c"
    # Room for the ellipsis whenever more text follows.
    if ((used + W > $2 - 1 && i < ${#s} - 1)) || ((used + W > $2)); then
      res+="…"
      break
    fi
    res+="$c"
    used=$((used + W))
  done
  res="${res//&/&amp;}"
  res="${res//</&lt;}"
  printf '%s' "${res//>/&gt;}"
}

# What is PLAYING first (Spotify ahead of the rest), then a paused Spotify, then anything. The bar
# puts Spotify first even paused; a lock card answers "what is playing", so playing wins here.
render() {
  local name status title artist rank best=-1 b_status="" b_title="" b_artist="" markup glyph
  while IFS="$sep" read -r name status title artist; do
    [ -n "$name" ] || continue
    rank=0
    case "${name,,}" in spotify*) rank=1 ;; esac
    if [ "$status" = Playing ]; then rank=$((rank + 2)); fi
    if ((rank > best)); then best=$rank b_status=$status b_title=$title b_artist=$artist; fi
  done < <(playerctl --all-players metadata \
    --format "{{playerName}}$sep{{status}}$sep{{xesam:title}}$sep{{artist}}" 2> /dev/null || true)

  if ((best < 0)) || [ -z "$b_title" ] || [ "$b_status" = Stopped ]; then
    markup="<span foreground=\"#$LOCK_COL_SUBTEXT\">$LOCK_TXT_NO_MEDIA</span>"
  else
    glyph="󰐊"
    [ "$b_status" = Playing ] || glyph="󰏤"
    markup="$glyph  <b>$(fit "$b_title" "$LOCK_TITLE_COLS")</b>"
    if [ -n "$b_artist" ]; then
      markup+=$'\n'"<span foreground=\"#$LOCK_COL_SUBTEXT\">$(fit "$b_artist" "$LOCK_ARTIST_COLS")</span>"
    fi
  fi
  # The bridge's PID first: the label hides the text once this process is gone.
  printf '%s\n%s' "$$" "$markup" > "$out.$$" && mv -f "$out.$$" "$out"
}

render
# One line per change of anything the format names; the line itself is only the trigger.
playerctl --all-players --follow metadata --format '{{playerName}}{{status}}{{xesam:title}}{{artist}}' 2> /dev/null |
  while read -r _; do render; done
