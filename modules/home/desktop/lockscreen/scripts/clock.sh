# shellcheck shell=bash
# The clock label's command, INLINED into hyprlock.conf by Nix with the @…@ values from the type and
# palette: one sh, builtins only, both fields from ONE instant. Tabular digits, small seconds.
t=$EPOCHSECONDS; printf '<span font_features="tnum">%(%H:%M)T</span><span font_desc="@SECONDS@" rise="@RISE@" foreground="#@ACCENT@"> %(%S)T</span>' "$t" "$t"
