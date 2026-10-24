# ZapFast: a native WhatsApp client linked as a companion device (~200 MB instead of a browser tab).
# Unofficial, so it carries a ban risk; the trade-off and the fallback: docs/notes/apps/zapfast.md
{ pkgs, ... }:

{
  home.packages = [ pkgs.zapfast ]; # the vendored release binary, pkgs/zapfast
}
