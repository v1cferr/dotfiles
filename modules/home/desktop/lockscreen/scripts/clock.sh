# shellcheck shell=bash
# The clock label's command, INLINED into hyprlock.conf by Nix with @ACCENT@ from the palette: one sh,
# builtins only, both fields from ONE instant. HH:MM:SS at one size, tabular, the seconds quieter.
t=$EPOCHSECONDS; printf '<span font_features="tnum">%(%H:%M)T<span foreground="#@ACCENT@" alpha="85%%">:%(%S)T</span></span>' "$t" "$t"
