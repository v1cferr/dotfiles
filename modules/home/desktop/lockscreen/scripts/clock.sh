# shellcheck shell=bash
# The clock label's command, INLINED into hyprlock.conf by Nix with @ACCENT@ from the palette: one sh,
# builtins only, both fields from ONE instant so a minute never changes under its seconds.
t=$EPOCHSECONDS; printf '%(%H:%M)T<span foreground="#@ACCENT@">:%(%S)T</span>' "$t" "$t"
