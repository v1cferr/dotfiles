# shellcheck shell=bash
# The clock label's command, INLINED into hyprlock.conf by Nix (the @…@ from the palette and the session):
# one sh, builtins only, one instant for both fields, in the ASUS print's ink. HH:MM:SS at one size.
t=$EPOCHSECONDS; c=@TEXT@ a=@ACCENT@; read -r k 2>/dev/null <@INK@; [ "$k" = dark ] && c=@DARK@ a=@DARKACCENT@; printf '<span foreground="#%s" font_features="tnum">%(%H:%M)T<span foreground="#%s" alpha="85%%">:%(%S)T</span></span>' "$c" "$t" "$a" "$t"
