# A keybind cheatsheet in Vicinae's dmenu (SUPER+H), GENERATED from keybinds.lua at runtime so it
# can never drift. The awk parser's rules and why not SUPER+/: docs/notes/desktop/desktop-plumbing.md
{ config, pkgs, ... }:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    gawk
    libnotify
    writeShellApplication
    writeText
    ;

  vicinae = config.programs.vicinae.package;

  # The parser. Its rules, and the 2 details that broke earlier versions, are in the notes.
  parser = writeText "keybinds-cheatsheet.awk" ''
    function clean(c) { sub(/^-- ?/, "", c); gsub(/─/, "", c); sub(/^ +| +$/, "", c); return c }
    function short(t) {
      # it cuts only at the 1st ". ", never at ": ", or "Mouse: move…" would become "Mouse"
      if (match(t, /\. /)) t = substr(t, 1, RSTART - 1)
      sub(/[.:]$/, "", t)
      if (length(t) > 66) t = substr(t, 1, 63) "…"
      return t
    }
    function tailcomment(l,   p, best) {
      best = 0; p = index(l, " -- ")
      while (p > 0) { best = p; p = index(substr(l, best + 4), " -- "); if (p > 0) p += best + 3 }
      return best ? substr(l, best + 4) : ""
    }
    function pretty(k,   n, a, i, o, t) {
      n = split(k, a, / *\+ */); o = ""
      for (i = 1; i <= n; i++) {
        t = a[i]
        if      (t == "comma")       t = ","
        else if (t == "period")      t = "."
        else if (t == "mouse_left")  t = "wheel ←"
        else if (t == "mouse_right") t = "wheel →"
        else if (t == "mouse_up")    t = "wheel ↑"
        else if (t == "mouse_down")  t = "wheel ↓"
        else if (t == "mouse:272")   t = "left click"
        else if (t == "mouse:273")   t = "right click"
        else if (t == "mouse:274")   t = "middle click"
        else if (t == "left")  t = "←"; else if (t == "right") t = "→"
        else if (t == "up")    t = "↑"; else if (t == "down")  t = "↓"
        else if (t == "RETURN") t = "Enter"; else if (t == "ESCAPE" || t == "escape") t = "Esc"
        else if (t == "BACKSPACE") t = "Backspace"
        o = (o == "" ? t : o " + " t)
      }
      return o
    }
    /^[[:space:]]*$/ { inblk = 0; next }
    /hl\.define_submap\(/ { if (match($0, /"[^"]+"/)) submap = substr($0, RSTART + 1, RLENGTH - 2); next }
    /^end\)/ { submap = ""; next }
    /^--/ { if (!inblk) { blk = clean($0); inblk = 1 } next }
    /^[[:space:]]*hl\.bind\(/ {
      inblk = 0
      if (blk != "") { group = blk; blk = "" }
      line = $0
      desc = tailcomment(line); sub(/ +$/, "", desc)
      k = line; sub(/^[^(]*\(/, "", k); sub(/,.*$/, "", k)
      gsub(/mainMod/, "\"SUPER\"", k); gsub(/ *\.\. */, "", k); gsub(/"/, "", k)
      if (k ~ /i$/) sub(/i$/, "1…8", k)
      gsub(/  +/, " ", k); sub(/^ +| +$/, "", k)
      if (desc == "") desc = short(group)
      if (submap != "") desc = "[submap " submap "] " desc
      printf "%-26s  %s\n", pretty(k), desc
    }
  '';

  cheatsheet = writeShellApplication {
    name = "keybinds-cheatsheet";
    runtimeInputs = [
      gawk
      libnotify
      vicinae
    ];
    text = ''
      src="$HOME/.config/hypr/lua/keybinds.lua"
      # It fails LOUDLY: an empty list would lie by saying there are no binds.
      fail() {
        notify-send -u critical -a Keybinds "keybinds-cheatsheet" "$1"
        echo "$1" >&2
        exit 1
      }
      [ -r "$src" ] || fail "could not read $src"
      rows="$(awk -f ${parser} "$src")" || fail "the parser failed on $src"
      [ -n "$rows" ] || fail "the parser found no binds in $src"
      # dmenu exits non-zero on Esc too, so a dead server is checked first and named.
      vicinae ping >/dev/null 2>&1 || fail "the Vicinae server is not running (systemctl --user status vicinae)"
      # It only displays: the choice is discarded, since this is a reference, not an action runner.
      printf '%s\n' "$rows" |
        vicinae dmenu -n Keybinds -p "Filter shortcuts" -s "{count} binds" --no-quick-look >/dev/null ||
        true
    '';
  };
in
{
  home.packages = [ cheatsheet ];
}
