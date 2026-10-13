# LIBREWOLF: the browser plus the palette on its frame, through userChrome and not a theme add-on,
# which would need signature checks off for every add-on: docs/notes/apps/librewolf.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs) librewolf writeText;

  p = config.my.theme.palette; # SSOT: modules/home/desktop/palette.nix (rule 11, decision 0001)
  c = name: "#${p.${name}}";

  # Without this pref Gecko ignores chrome/userChrome.css; a defaultPref in the package, so the
  # profile carries no user.js of ours.
  package = librewolf.override {
    extraPrefs = ''defaultPref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'';
  };

  # EVERY line `!important`, to win over the browser's author sheets. Each name was MEASURED in
  # LibreWolf 157 (the theme API's --lwt-*/--arrowpanel-* are no longer read). Same steps as Zen:
  # frame on bg, toolbar and selected tab on surface, hover on track.
  userChrome = writeText "userChrome.css" ''
    :root {
      --toolbar-background-color: ${c "surface"} !important;
      --toolbar-text-color: ${c "text"} !important;
      --tab-background-color-selected: ${c "surface"} !important;
      --tab-background-color-hover: ${c "track"} !important;
      --tab-text-color-selected: ${c "text"} !important;
      --toolbar-field-background-color: ${c "bg"} !important; /* the address bar */
      --toolbar-field-border-color: ${c "border"} !important;
      --toolbar-field-text-color: ${c "text"} !important;
      --urlbar-background-color-focus: ${c "bg"} !important;
      --toolbar-field-text-color-focus: ${c "text"} !important;
      --focus-outline-color: ${c "accent"} !important;
      --panel-background-color: ${c "surface"} !important; /* menus and popups */
      --panel-text-color: ${c "text"} !important;
      --panel-border-color: ${c "border"} !important;
    }
    /* The frame behind the tabs has no variable: it is the system's header bar color. */
    #navigator-toolbox {
      background-color: ${c "bg"} !important;
      color: ${c "subtext"} !important; /* background tabs */
    }
  '';
in
{
  home.packages = [ package ];

  # The profile dir is a random name LibreWolf chose, so it is read from profiles.ini and not
  # written here. No profile yet, nothing to link: the next activation does it.
  home.activation.librewolfTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    root="$HOME/.config/librewolf/librewolf"
    rel=$(sed -n 's/^Path=//p' "$root/profiles.ini" 2>/dev/null | head -1)
    if [ -n "$rel" ] && [ -d "$root/$rel" ]; then
      run mkdir -p "$root/$rel/chrome"
      run ln -sfn ${userChrome} "$root/$rel/chrome/userChrome.css"
    fi
  '';
}
