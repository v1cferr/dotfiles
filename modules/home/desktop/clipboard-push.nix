# CLIPBOARD-PUSH: the clipboard's image or file scp'd to a host (or dropped locally), leaving its
# PATH in the clipboard; SUPER+ALT+V and kitty's smart paste: docs/notes/desktop/desktop-plumbing.md
{ pkgs, ... }:

let
  inherit (pkgs)
    coreutils
    gnugrep
    libnotify
    openssh
    wl-clipboard
    writeShellApplication
    writeText
    ;

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
        # Two connections, one handshake: `workstation` multiplexes (ControlMaster, modules/home/shell/ssh.nix).
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
  home.packages = [ clipboardPush ];
}
