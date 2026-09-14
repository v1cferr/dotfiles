# CLIPBOARD: cliphist plus a rofi picker (a THUMBNAIL and an icon per type), and clipboard-push,
# which scp's it to a remote host. rofi is declared HERE: docs/notes/desktop/desktop-plumbing.md
{
  pkgs,
  config,
  osConfig,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    cliphist
    coreutils
    gnugrep
    libnotify
    openssh
    rofi
    wl-clipboard
    writeShellApplication
    writeText
    ;

  palette = config.my.theme.palette; # the active theme's colors (home/desktop/palette.nix)
  # clipboard-menu: one pass (list, rofi, decode, copy), with 3 cases: an image becomes a
  # THUMBNAIL, a file:// URI gets a named icon for its type, and text gets the text icon.
  clipboardMenu = writeShellApplication {
    name = "clipboard-menu";
    runtimeInputs = [
      cliphist
      wl-clipboard
      rofi
      coreutils
      gnugrep
    ];
    text = ''
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/thumbnails"
      mkdir -p "$cache"

      # extension to a freedesktop icon name, resolved by the active icon theme.
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
  # What runs ON THE REMOTE, through its stdin (the same trick as `wake-workstation`, so there is
  # nothing to install over there): it creates the drop, prunes the week-old files and answers the
  # ABSOLUTE path, which is what scp and the TUI both need.
  remoteDrop = writeText "clipboard-drop.sh" ''
    d="$HOME/.cache/clipboard-push"
    mkdir -p "$d"
    find "$d" -type f -mtime +7 -delete 2>/dev/null
    printf %s "$d"
  '';

  # clipboard-push: the clipboard to a file (over scp, or `local` right here), leaving its PATH in
  # the clipboard. It is how an image reaches a TUI: docs/notes/desktop/desktop-plumbing.md
  clipboardPush = writeShellApplication {
    name = "clipboard-push";
    runtimeInputs = [
      wl-clipboard
      openssh
      coreutils
      gnugrep
      libnotify
    ];
    text = ''
      dest="''${1:-workstation}" # an ssh Host of ~/.ssh/config, or `local` for a drop on this machine

      note() { notify-send -a Clipboard -i edit-paste "clipboard-push" "$1" 2>/dev/null || true; }
      fail() {
        notify-send -a Clipboard -u critical -i dialog-error "clipboard-push" "$1" 2>/dev/null || true
        echo "$1" >&2
        exit 1
      }

      # An IMAGE wins; failing that, a copied FILE, which Dolphin leaves as a file:// URI.
      mime="$(wl-paste --list-types 2>/dev/null | grep -m1 '^image/' || true)"
      if [ -n "$mime" ]; then
        ext="''${mime#image/}"
        [ "$ext" = jpeg ] && ext=jpg
        src="$(mktemp --suffix=".$ext")"
        trap 'rm -f "$src"' EXIT
        wl-paste --no-newline --type "$mime" > "$src" || fail "the image could not be read"
        name="clip-$(date +%Y%m%d-%H%M%S).$ext"
      else
        uri="$(wl-paste --no-newline 2>/dev/null || true)"
        case "$uri" in
          # %XX becomes \xXX and printf decodes it: a file:// URI encodes spaces and accents.
          file://*) enc="''${uri#file://}"; src="$(printf '%b' "''${enc//%/\\x}")" ;;
          /*) src="$uri" ;;
          *) src="" ;;
        esac
        if [ -z "$src" ] || [ ! -f "$src" ]; then fail "there is no image or file in the clipboard"; fi
        name="$(basename "$src")"
      fi

      if [ "$dest" = local ]; then
        # An image only exists in a temp file and has to land somewhere; a copied file is already
        # on disk, so its own path is the answer and nothing is duplicated.
        if [ -n "$mime" ]; then
          dir="''${XDG_CACHE_HOME:-$HOME/.cache}/clipboard-push"
          mkdir -p "$dir"
          find "$dir" -type f -mtime +7 -delete 2>/dev/null || true
          mv "$src" "$dir/$name"
        else
          dir="$(dirname "$src")"
        fi
      else
        # Two connections, one handshake: `workstation` multiplexes (ControlMaster, home/shell/ssh.nix).
        dir="$(ssh -o BatchMode=yes "$dest" sh -s < ${remoteDrop})" ||
          fail "$dest did not answer (is the VPN up?)"
        scp -q "$src" "$dest:$dir/$name" || fail "the transfer to $dest failed"
      fi

      # NO trailing newline: pasted into a TUI, one would SUBMIT the prompt instead of typing it.
      wl-copy "$dir/$name"
      echo "$dir/$name"
      note "$dest: $dir/$name"
    '';
  };
in
{
  # cliphist's declarative service (it replaced the `wl-paste --watch` in hypr's autostart).
  services.cliphist = {
    enable = true;
    allowImages = true;
  };

  home.packages = [
    rofi # the picker with -show-icons (an image thumbnail / an icon per type)
    clipboardMenu
    clipboardPush
  ];

  # The colors follow my.theme, so a preset switch recolors this too. An explicit `font` is
  # required, and '#' inside a .rasi opens a COLOR literal, not a comment.
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
