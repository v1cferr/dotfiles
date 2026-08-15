# A keybind cheatsheet in rofi (SUPER+H), listing ALL the Hyprland binds.
#
# GENERATED from keybinds.lua at RUNTIME, never written by hand: a duplicated list would become
# a lie on the first new bind. The file it reads is ~/.config/hypr/lua/keybinds.lua, which is a
# mkOutOfStoreSymlink into the repo (home/desktop/hypr.nix), so the cheatsheet even follows a
# hot-reload edit, with no rebuild.
#
# Why SUPER+H and not SUPER+/: Moonlight does NOT send the ABNT2 "/ ?" key (bug #1789, the same
# reason as the ScrollLock remap in keybinds.lua), so SUPER+/ would die over remote access. H is
# free and gets through on any path.
#
# The rofi package comes from clipboard.nix (do not redeclare it, since it is the same tool for
# the launcher, the clipboard and here).
{
  pkgs,
  config,
  osConfig,
  ...
}:

let
  palette = config.my.theme.palette; # the active theme's colors (home/desktop/palette.nix)

  # A parser in awk. The rules it follows, all dictated by keybinds.lua's real format:
  #   • the group       = the 1st line of the comment block right ABOVE the bind;
  #   • the description = the comment at the END of the bind's line; with none, it falls back to
  #                       the group's text;
  #   • the submap      = binds inside hl.define_submap get a prefix, otherwise "1"/"2"/"Esc"
  #                       would show up loose and meaningless in the list.
  # Two details that broke earlier versions and are therefore explicit:
  #   • the comment is found by the LAST " -- " on the line, not by a "no hyphen" regex:
  #     legitimate descriptions contain a hyphen ("no-op", "qs-restart") and were disappearing;
  #   • the keys are translated TOKEN BY TOKEN (comma to ","), not with a blind gsub, otherwise
  #     the "left" inside "mouse_left" would be substituted too.
  parser = pkgs.writeText "keybinds-cheatsheet.awk" ''
    function clean(c) { sub(/^-- ?/, "", c); gsub(/─/, "", c); sub(/^ +| +$/, "", c); return c }
    function short(t) {
      # it cuts only at the 1st ". " (the end of a sentence). Do NOT cut at ": ", since groups
      # like "Mouse: move / resize the window" would become the useless "Mouse".
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

  cheatsheet = pkgs.writeShellApplication {
    name = "keybinds-cheatsheet";
    runtimeInputs = with pkgs; [
      gawk
      rofi
    ];
    text = ''
      src="$HOME/.config/hypr/lua/keybinds.lua"
      # It fails LOUDLY if the symlink disappears: an empty cheatsheet would lie by saying
      # "there are no binds".
      if [ ! -r "$src" ]; then
        rofi -e "keybinds-cheatsheet: could not read $src" -theme cheatsheet
        exit 1
      fi
      # It only displays: the choice is discarded (it is a reference, not an action runner).
      awk -f ${parser} "$src" | rofi -dmenu -i -p "󰌌 Keybinds" -theme cheatsheet > /dev/null
    '';
  };
in
{
  home.packages = [ cheatsheet ];

  # An explicit `font`: without it rofi falls back to the default "mono 12". my.fonts.ui is also
  # the system monospace (system/hardware/fonts.nix), so the columns line up.
  # Do NOT comment inside the .rasi with '#': there '#' opens a color literal and breaks the
  # parse.
  xdg.configFile."rofi/cheatsheet.rasi".text = ''
    configuration {
      show-icons: false;
      matching:   "fuzzy";
      font:       "${osConfig.my.fonts.ui} 11";
    }
    * {
      tn-bg:     #${palette.bg};
      tn-bg-alt: #${palette.surface};
      tn-fg:     #${palette.text};
      tn-muted:  #${palette.dim};
      tn-blue:   #${palette.blue};
      background-color: transparent;
      text-color:       @tn-fg;
    }
    window {
      width:            900px;
      background-color: @tn-bg;
      border:           2px;
      border-color:     @tn-blue;
      border-radius:    12px;
      padding:          14px;
    }
    mainbox { spacing: 12px; children: [ inputbar, listview ]; }
    inputbar {
      background-color: @tn-bg-alt;
      border-radius:    8px;
      padding:          10px 14px;
      spacing:          8px;
      children:         [ prompt, entry ];
    }
    prompt { text-color: @tn-blue; }
    entry  { placeholder: "Filter by key or action…"; placeholder-color: @tn-muted; }
    listview { lines: 20; columns: 1; scrollbar: true; spacing: 2px; }
    scrollbar { handle-color: @tn-blue; handle-width: 4px; }
    element { padding: 4px 10px; border-radius: 6px; }
    element normal.normal   { background-color: transparent; text-color: @tn-fg; }
    element selected.normal { background-color: @tn-blue;     text-color: @tn-bg; }
  '';
}
