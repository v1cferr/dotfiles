# ZEN THEME: the desktop palette on Zen's OWN variables, not on its selectors, so an update that
# renames an element cannot break it. The toggle and the measurements: docs/notes/apps/zen.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (pkgs)
    coreutils
    jq
    procps
    python3
    writeShellApplication
    writeText
    ;

  p = config.my.theme.palette; # the single source (modules/home/desktop/palette.nix)
  c = name: "#${p.${name}}";

  # EVERY line `!important`: userChrome is a USER sheet, which loses to Zen's author sheet and to
  # the inline styles the gradient generator writes on <html> (ZenGradientGenerator.mjs) unless
  # it is important. The rest Zen derives from --zen-primary-color and --zen-branding-dark
  # (zen-theme.css), so they follow on their own. Wrapped in a pref so the stock theme is one
  # about:config flip away, live, no rebuild.
  userChrome = writeText "userChrome.css" ''
    @media not -moz-pref("my.zen.stock-theme") {
      /* The gradient generator writes these INLINE on the two background elements themselves,
         so a :root value alone never reaches what is painted (measured in the lab: #131313). */
      :root,
      #zen-browser-background,
      #zen-toolbar-background {
        --zen-main-browser-background: ${c "bg"} !important;
        --zen-main-browser-background-toolbar: ${c "bg"} !important;
        --zen-main-browser-background-old: ${c "bg"} !important;
        --zen-main-browser-background-toolbar-old: ${c "bg"} !important;
      }
      /* Each space (zen-workspace) redefines these, inline or in its own rule, so the tab list
         ignored :root until the space was listed too. */
      :root,
      zen-workspace {
        --zen-primary-color: ${c "accent"} !important;
        --toolbox-textcolor: ${c "text"} !important;
        /* Three steps from the palette: bg, then hover on surface, then selected on track. Zen's
           own were 22% of the text color and a 7% gray, so hover outshone the selected tab. */
        --tab-background-color-hover: ${c "surface"} !important;
        --tab-background-color-selected: ${c "track"} !important;
      }
      :root {
        --tab-text-color-selected: ${c "text"} !important;
        --input-color: ${c "text"} !important; /* the address bar; Zen still dims it to 70% at rest */
        --zen-big-shadow: none !important; /* the page's 8px drop shadow, for a flat frame */
        --arrowpanel-background: ${c "surface"} !important; /* menus and panels */
        --arrowpanel-color: ${c "text"} !important;
        --arrowpanel-border-color: ${c "border"} !important;
        --zen-branding-dark: ${c "bg"} !important;
        --zen-themed-toolbar-bg-transparent: ${c "bg"} !important;
        --zen-dialog-background: ${c "surface"} !important;
        --zen-urlbar-background: ${c "surface"} !important;
        --zen-colors-border: ${c "border"} !important;
        --zen-input-border-color: ${c "border"} !important;
      }
      /* The two that no variable reaches. The suggestions popup is a 15% white over a black
         native backdrop; the hovered-link status bar is drawn in GTK's -moz-dialog. */
      #urlbar .urlbar-background {
        background: ${c "surface"} !important;
        border-color: ${c "border"} !important;
      }
      #statuspanel-label {
        background-color: ${c "surface"} !important;
        border-color: ${c "border"} !important;
        color: ${c "subtext"} !important;
      }
    }
  '';

  # Only what the theme NEEDS: without it Gecko ignores chrome/userChrome.css altogether.
  userJs = writeText "user.js" ''
    user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
  '';

  # THE LAB: a SECOND Zen on a throwaway profile, with Marionette on, so the theme can be measured,
  # restyled live and photographed without touching the real profile (its cookies and passwords).
  # It loads the SAME generated sheet as production, and runs behind the same guard.
  labPort = "2829"; # not Marionette's 2828, so a stray session elsewhere cannot answer
  lab = writeShellApplication {
    name = "zen-theme-lab";
    runtimeInputs = [
      coreutils
      jq
      procps
      python3
    ];
    text = ''
      dir="''${XDG_RUNTIME_DIR:?}/zen-theme-lab"
      client() { python3 ${./lab.py} ${labPort} "$@"; }

      case "''${1:-}" in
      start)
        pkill -f -- "--profile $dir" || true
        rm -rf "$dir" && mkdir -p "$dir/chrome"
        ln -s ${userChrome} "$dir/chrome/userChrome.css"
        {
          cat ${userJs}
          echo 'user_pref("marionette.port", ${labPort});'
          echo 'user_pref("browser.shell.checkDefaultBrowser", false);'
          echo 'user_pref("zen.welcome-screen.seen", true);'
        } > "$dir/user.js"
        MOZ_REMOTE_ALLOW_SYSTEM_ACCESS=1 setsid ${config.my.zen.package}/bin/zen-beta \
          --profile "$dir" --no-remote --marionette --name zen-lab "''${2:-about:blank}" \
          > "$dir.log" 2>&1 &
        # Out of sight: a special workspace, never the one I am working on.
        for _ in {1..60}; do
          addr=$(hyprctl clients -j | jq -r '.[] | select(.class == "zen-lab") | .address' | head -1)
          [ -n "$addr" ] && break
          sleep 0.5
        done
        [ -n "''${addr:-}" ] || { echo "zen-theme-lab: no window after 30 s, see $dir.log" >&2; exit 1; }
        hyprctl dispatch "hl.dsp.window.move({workspace=\"special:zenlab\", window=\"address:$addr\", follow=false})" > /dev/null
        echo "lab up on port ${labPort}, window hidden on special:zenlab"
        ;;
      eval | css | shot) client "$@" ;;
      stop)
        client quit || true
        # Zen writes its profile on the way out, so the cleanup waits for the process to be gone.
        for _ in {1..40}; do
          pgrep -f -- "--profile $dir" > /dev/null || break
          sleep 0.25
        done
        rm -rf "$dir" "$dir.log"
        ;;
      *)
        echo "usage: zen-theme-lab start [URL] | eval JS | css FILE|- | shot OUT.png | stop" >&2
        exit 2
        ;;
      esac
    '';
  };
in
{
  home.packages = [ lab ];

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
