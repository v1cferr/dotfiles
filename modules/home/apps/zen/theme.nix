# ZEN THEME: the desktop palette on Zen's OWN variables, not on its selectors, so an update that
# renames an element cannot break it. The toggle and the measurements: docs/notes/apps/zen.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs) writeText;

  p = config.my.theme.palette; # the single source (modules/home/desktop/palette.nix)
  c = name: "#${p.${name}}";

  # EVERY line `!important`: userChrome is a USER sheet, which loses to Zen's author sheet and to
  # the inline styles the gradient generator writes on <html> (ZenGradientGenerator.mjs) unless
  # it is important. The rest Zen derives from --zen-primary-color and --zen-branding-dark
  # (zen-theme.css), so they follow on their own. Wrapped in a pref so the stock theme is one
  # about:config flip away, live, no rebuild.
  userChrome = writeText "userChrome.css" ''
    @media not -moz-pref("my.zen.stock-theme") {
      :root {
        --zen-primary-color: ${c "accent"} !important;
        --zen-main-browser-background: ${c "bg"} !important;
        --zen-main-browser-background-toolbar: ${c "bg"} !important;
        --toolbox-textcolor: ${c "text"} !important;
        --zen-branding-dark: ${c "bg"} !important;
        --zen-themed-toolbar-bg-transparent: ${c "bg"} !important;
        --zen-dialog-background: ${c "surface"} !important;
        --zen-urlbar-background: ${c "surface"} !important;
        --zen-colors-border: ${c "border"} !important;
        --zen-input-border-color: ${c "border"} !important;
      }
    }
  '';

  # Only what the theme NEEDS: without it Gecko ignores chrome/userChrome.css altogether.
  userJs = writeText "user.js" ''
    user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
  '';
in
{
  # The profile dir is a random name Zen chose, so it is LOOKED UP (by the guard, the lookup's only
  # owner) and not written here. No profile yet, nothing to link: the next activation does it.
  home.activation.zenTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if profile=$(${lib.getExe config.my.zen.guard} profile); then
      run mkdir -p "$profile/chrome"
      run ln -sfn ${userChrome} "$profile/chrome/userChrome.css"
      run ln -sfn ${userJs} "$profile/user.js"
    fi
  '';
}
