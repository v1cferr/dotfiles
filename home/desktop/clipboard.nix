# A clipboard manager (Wayland): history with an image PREVIEW plus an icon per file TYPE.
# cliphist stores text/image/URI (a declarative service); the picker is rofi (-show-icons) with a
# Tokyo Night theme. The SUPER+SHIFT+V bind lives in home/desktop/hypr/lua/keybinds.lua. It
# replaces the old wofi picker (text only).
#
# Migrated from my Arch (cliphist-rofi-img.sh) WITH improvements: besides the image thumbnail,
# copied files (a file://… URI) now get an ICON for their type (zip/video/pdf and so on)
# resolved by the active icon theme (my.theme.iconTheme). Rules 1 and 3: idiomatic and
# declarative.
{
  pkgs,
  config,
  osConfig,
  ...
}:

let
  palette = config.my.theme.palette; # the active theme's colors (home/desktop/palette.nix)
  # clipboard-menu: it builds the cliphist list with icons and shows it in rofi; the choice goes
  # back to the clipboard (paste it with Ctrl+V). A single pass (list, rofi, decode, copy).
  #   • an image (binary png/jpg/…) -> decoded into the cache and used as a THUMBNAIL
  #   • a file (a file://… URI)     -> a NAMED icon for the type (from the extension)
  #   • text                        -> a text icon
  clipboardMenu = pkgs.writeShellApplication {
    name = "clipboard-menu";
    runtimeInputs = with pkgs; [
      cliphist
      wl-clipboard
      rofi
      coreutils
      gnugrep
    ];
    text = ''
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/thumbnails"
      mkdir -p "$cache"

      # extension -> a freedesktop icon name (resolved by the active icon theme).
      ext_icon() {
        case "$1" in
          zip|tar|gz|xz|bz2|7z|rar|zst)             echo application-x-archive ;;
          mp4|mkv|avi|mov|webm|flv|wmv|m4v)         echo video-x-generic ;;
          mp3|flac|wav|ogg|opus|m4a|aac)            echo audio-x-generic ;;
          png|jpg|jpeg|gif|bmp|webp|svg|tiff|ico)   echo image-x-generic ;;
          pdf)                                      echo application-pdf ;;
          doc|docx|odt|rtf)                         echo x-office-document ;;
          xls|xlsx|ods|csv)                         echo x-office-spreadsheet ;;
          sh|bash|zsh|py|js|ts|lua|nix|c|cpp|rs|go|java|rb) echo text-x-script ;;
          txt|md|log|json|xml|yaml|yml|toml|conf|ini)       echo text-x-generic ;;
          iso|img|bin|exe|appimage)                 echo application-x-executable ;;
          *)                                        echo application-x-generic ;;
        esac
      }

      # it builds the rofi entry (line plus \0icon\x1f<icon>) per item and pipes it into rofi.
      choice="$(
        cliphist list | while IFS= read -r line; do
          case "$line" in
            *"binary data"*)
              ext="$(printf '%s' "$line" | grep -oiE '[[:space:]](png|jpe?g|bmp|gif|webp)[[:space:]]' | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | head -1)"
              if [ -n "$ext" ]; then
                [ "$ext" = jpeg ] && ext=jpg
                id="$(printf '%s' "$line" | cut -f1)"
                thumb="$cache/$id.$ext"
                [ -f "$thumb" ] || { printf '%s' "$line" | cliphist decode > "$thumb" 2>/dev/null || true; }
                printf '%s\0icon\x1f%s\n' "$line" "$thumb"
              else
                printf '%s\0icon\x1fapplication-x-generic\n' "$line"
              fi
              ;;
            *file://*)
              e="$(printf '%s' "$line" | grep -oiE '\.[A-Za-z0-9]+' | tail -1 | tr -d '.' | tr '[:upper:]' '[:lower:]')"
              printf '%s\0icon\x1f%s\n' "$line" "$(ext_icon "$e")"
              ;;
            *)
              printf '%s\0icon\x1ftext-x-generic\n' "$line"
              ;;
          esac
        done | rofi -dmenu -i -show-icons -p "󰅇 Clipboard" -theme clipboard
      )"

      [ -n "$choice" ] || exit 0
      printf '%s' "$choice" | cliphist decode | wl-copy
    '';
  };
in
{
  # cliphist's declarative service (it replaces the `wl-paste --watch` from hypr's autostart).
  # allowImages also brings up the image watcher, on top of the text one.
  services.cliphist = {
    enable = true;
    allowImages = true;
  };

  home.packages = [
    pkgs.rofi # the picker with -show-icons (an image thumbnail / an icon per type)
    clipboardMenu
  ];

  # The ACTIVE THEME's colors (my.theme): rofi's palette follows the single source. icon-theme
  # comes from my.theme.iconTheme (the same one as the system) and resolves the icons named per
  # file type. An explicit `font`: without it rofi falls back to the default "mono 12". Do NOT
  # comment inside the .rasi with '#', since there '#' opens a color literal and breaks the parse
  # of the whole theme.
  xdg.configFile."rofi/clipboard.rasi".text = ''
    configuration {
      show-icons:  true;
      icon-theme:  "${config.my.theme.iconTheme}";
      font:        "${osConfig.my.fonts.ui} 12";
    }
    * {
      tn-bg:     #${palette.bg};
      tn-bg-alt: #${palette.surface};
      tn-fg:     #${palette.text};
      tn-muted:  #${palette.dim};
      tn-blue:   #${palette.blue};
      tn-border: #${palette.border};
      background-color: transparent;
      text-color:       @tn-fg;
    }
    window {
      width:            720px;
      background-color: @tn-bg;
      border:           2px;
      border-color:     @tn-blue;
      border-radius:    12px;
      padding:          12px;
    }
    mainbox { spacing: 10px; children: [ inputbar, listview ]; }
    inputbar {
      background-color: @tn-bg-alt;
      border-radius:    8px;
      padding:          8px 12px;
      spacing:          8px;
      children:         [ prompt, entry ];
    }
    prompt { text-color: @tn-blue; }
    entry  { placeholder: "search…"; placeholder-color: @tn-muted; }
    listview { lines: 8; columns: 1; scrollbar: false; spacing: 4px; }
    element {
      padding:       6px 8px;
      spacing:       10px;
      border-radius: 8px;
      children:      [ element-icon, element-text ];
    }
    element normal.normal   { background-color: transparent; text-color: @tn-fg; }
    element selected.normal { background-color: @tn-blue;     text-color: @tn-bg; }
    element-icon { size: 2.2em; vertical-align: 0.5; }
    element-text { vertical-align: 0.5; }
  '';
}
