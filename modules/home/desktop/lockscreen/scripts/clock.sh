# shellcheck shell=bash
# The clock label's command, INLINED into hyprlock.conf by Nix: one sh and a builtin, no second exec
# (2.0 ms of CPU per tick against 3.8 for a script, measured). Its LAST line is the command.
printf '%(%H:%M:%S)T' -1
