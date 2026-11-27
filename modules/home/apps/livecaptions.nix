# LIVE CAPTIONS: live English captions for ANY audio on the desktop (aprilasr, local, CPU).
# The window rule and the SUPER+SHIFT+C toggle are in hypr/lua; why this app: docs/notes/apps/livecaptions.md
{ pkgs, ... }:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs) livecaptions;
in
{
  # The wrapper pins APRIL_MODEL_PATH to the English model in the store, so no download.
  home.packages = [ livecaptions ];

  dconf.settings."net/sapples/LiveCaptions" = {
    keep-on-top = true; # it asks to stay above; on Hyprland the window rule's pin does the work
    # A Flatpak install left `/app/...` here, which logged "aam: failed to read file" at every launch.
    installed-models = [ ];
  };
}
