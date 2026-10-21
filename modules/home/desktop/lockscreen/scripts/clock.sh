# shellcheck shell=bash
# The clock label's command, INLINED into hyprlock.conf by Nix (the @…@ from the palette and the session):
# one sh, builtins only, one instant for every field; empty unless the cartouche is on THIS label's side.
t=$EPOCHSECONDS; s=left; read -r s 2>/dev/null <@SIDE@; [ "$s" = @MYSIDE@ ] || exit 0; printf '<span font_features="tnum" line_height="0.82">%(%H)T\n%(%M)T\n<span foreground="#@SECONDS@">%(%S)T</span></span>' "$t" "$t" "$t"
