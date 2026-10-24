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
      /* A split pair reads as ONE entry, Arc's way: the first tab keeps the whole title and the
         others shrink to their icon. Zen halves the width, which cut both titles to the key. */
      tab-group[split-view-group] .tab-group-container {
        background: ${c "surface"} !important;
        border-radius: 10px !important;
        padding: 2px !important;
        gap: 2px;
      }
      tab-group[split-view-group] .tab-group-container > tab:first-of-type {
        flex: 1 1 auto !important;
      }
      tab-group[split-view-group] .tab-group-container > tab:not(:first-of-type) {
        flex: 0 0 32px !important;
      }
      tab-group[split-view-group] .tab-group-container > tab:not(:first-of-type) .tab-label-container {
        display: none !important;
      }
      tab-group[split-view-group] .tab-group-container > tab::after {
        display: none !important; /* Zen's | between the halves */
      }
      tab-group[split-view-group] .tabbrowser-tab .tab-background {
        background: transparent !important;
        border-radius: 8px !important;
      }
      /* On the pair's surface, the usual surface hover would not show, so both states use track. */
      tab-group[split-view-group] .tabbrowser-tab:is(:hover, [visuallyselected]) .tab-background {
        background: ${c "track"} !important;
      }
      tab-group[split-view-group] .tab-label {
        color: ${c "subtext"} !important;
      }
      tab-group[split-view-group][hasactivetab] .tab-label {
        color: ${c "text"} !important;
      }
      /* A folder's children hang from a hairline under its icon (VS Code / Linear tree guides),
         and pairs inside it drop their surface so the guide alone does the grouping. */
      zen-folder > .tab-group-container {
        position: relative;
      }
      zen-folder:not([collapsed]) > .tab-group-container::before {
        content: "";
        position: absolute;
        left: 19px; /* under the center of the folder icon */
        top: 2px;
        bottom: 4px;
        width: 1px;
        border-radius: 1px;
        background: ${c "border"}99;
      }
      zen-folder > .tab-group-container > :is(tab, tab-group, zen-folder) {
        margin-inline-start: 26px !important;
      }
      zen-folder > .tab-group-label-container .tab-group-label {
        color: ${c "subtext"} !important;
      }
      zen-folder tab-group[split-view-group] .tab-group-container {
        background: transparent !important;
      }
      /* The page lifted by the desktop's own window shadow (Hyprland: range 6, render_power 3,
         no offset), so it reads as a window in the window and not as a frame in the frame. */
      #tabbrowser-tabbox #tabbrowser-tabpanels .browserSidebarContainer {
        box-shadow: 0 0 2px ${c "shadow"}cc, 0 0 6px ${c "shadow"}99 !important;
      }
    }
  '';

  # Only what the theme NEEDS: without it Gecko ignores chrome/userChrome.css altogether.
  userJs = writeText "user.js" ''
    user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
    // SuperPins (a Zen mod installed in the profile) boxes every pin and pinned group for "pins",
    // "essentials" or "both"; any other value matches none of its rules, so no boxes.
    user_pref("uc.superpins.border", "none");
  '';

  # THE LAB: a SECOND Zen on a throwaway profile, with Marionette on, so the theme can be measured,
  # restyled live and photographed without touching the real profile (its cookies and passwords).
  # It loads the SAME generated sheet as production, and runs behind the same guard.
  labPort = "2829"; # not Marionette's 2828, so a stray session elsewhere cannot answer
  # A dependency-free Marionette client in the browser's CHROME context: `len:json` frames over
  # TCP. Why Marionette and not the DevTools MCP, and the lab's rules: docs/notes/apps/zen.md
  labClient = writeShellApplication {
    name = "zen-lab-client";
    runtimeInputs = [
      coreutils
      jq
    ];
    text = ''
      export LC_ALL=C # read -N counts BYTES, which is what the `len:` prefix counts

      port=$1 verb=$2 arg=''${3:-}

      # It loads ONE extra user sheet at a time, so a new `css` replaces the last instead of stacking.
      inject='
      const wu = window.windowUtils;
      if (window.__zenLabSheet) {
        try { wu.removeSheetUsingURIString(window.__zenLabSheet, wu.USER_SHEET); } catch (e) {}
        window.__zenLabSheet = null;
      }
      if (arguments[0]) {
        const uri = "data:text/css;charset=utf-8," + encodeURIComponent(arguments[0]);
        wu.loadSheetUsingURIString(uri, wu.USER_SHEET);
        window.__zenLabSheet = uri;
      }
      return Boolean(window.__zenLabSheet);
      '

      { exec 3<>"/dev/tcp/127.0.0.1/$port"; } 2>/dev/null || {
        echo "nothing on port $port: run \`zen-theme-lab start\` first" >&2
        exit 1
      }
      frame() { local size; IFS= read -r -d ':' size <&3; IFS= read -r -N "$size" reply <&3; }
      id=0
      # One command as [0, id, name, params]; the answer with the same id is [1, id, error, result].
      cmd() {
        local name=$1 params=''${2:-'{}'} data
        id=$((id + 1))
        data=$(jq -cn --argjson id "$id" --arg name "$name" --argjson params "$params" '[0, $id, $name, $params]')
        printf '%s:%s' "''${#data}" "$data" >&3
        while frame; do
          [[ "$(jq '.[1]' <<<"$reply")" == "$id" ]] || continue
          if [[ "$(jq -c '.[2]' <<<"$reply")" != null ]]; then
            echo "$name: $(jq -c '.[2]' <<<"$reply")" >&2
            exit 1
          fi
          result=$(jq -c '.[3]' <<<"$reply")
          return
        done
      }
      js() { cmd WebDriver:ExecuteScript "$(jq -cn --arg s "$1" '{script: $s, args: $ARGS.positional}' --args "''${@:2}")"; }

      frame # the server's hello
      cmd WebDriver:NewSession '{"capabilities": {}}'
      cmd Marionette:SetContext '{"value": "chrome"}'
      case "$verb" in
      eval) js "$arg" && jq --indent 1 '.value' <<<"$result" ;;
      css)
        if [[ -z "$arg" || "$arg" == - ]]; then css=$(cat); else css=$(<"$arg"); fi
        js "$inject" "$css"
        [[ "$(jq '.value' <<<"$result")" == true ]] && echo injected || echo cleared
        ;;
      shot) cmd WebDriver:TakeScreenshot '{"full": false}' && jq -r '.value' <<<"$result" | base64 -d >"$arg" && echo "$arg" ;;
      quit) (cmd Marionette:Quit '{"flags": ["eForceQuit"]}') 2>/dev/null || true ;; # it may close first
      *) echo "unknown verb: $verb" >&2; exit 1 ;;
      esac
    '';
  };
  lab = writeShellApplication {
    name = "zen-theme-lab";
    runtimeInputs = [
      coreutils
      jq
      procps
    ];
    text = ''
      dir="''${XDG_RUNTIME_DIR:?}/zen-theme-lab"
      client() { ${lib.getExe labClient} ${labPort} "$@"; }

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
