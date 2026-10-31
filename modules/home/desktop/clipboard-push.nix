# CLIPBOARD-PUSH: the clipboard's image or file scp'd to a host (or dropped locally), leaving its
# PATH in the clipboard; SUPER+ALT+V and kitty's smart paste: docs/notes/desktop/desktop-plumbing.md
{ osConfig, pkgs, ... }:

let
  inherit (pkgs)
    coreutils
    gnugrep
    jq
    libnotify
    openssh
    wl-clipboard
    writeShellApplication
    writeText
    ;
  # hyprctl from the RUNNING compositor (unstable), never the stable one a bare pkgs.hyprland is.
  hyprland = osConfig.programs.hyprland.package;

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
      jq
      libnotify
      hyprland
    ];
    text = ''
      # --image-only (Ctrl+V's bind in keybinds.lua): anything but an image is the window's own
      # paste, already delivered, so this exits quietly instead of pushing a copied file.
      if [ "''${1:-}" = --image-only ]; then
        shift
        wl-paste --list-types 2>/dev/null | grep -q '^image/' || exit 0
      fi

      # With no argument, a focused VS Code Remote-SSH window names the host in its title
      # (`... [SSH: workstation] - Visual Studio Code`) and gets the path pasted for it.
      vscode=""
      if [ -z "''${1:-}" ]; then
        win="$(hyprctl activewindow -j 2>/dev/null || true)"
        if [ "$(jq -r '.class // empty' <<<"$win" 2>/dev/null)" = code ]; then
          host="$(jq -r '.title // empty' <<<"$win" | grep -oP '\[SSH: \K[^\]]+' || true)"
          if [ -n "$host" ]; then vscode="$(jq -r '.address' <<<"$win")"; fi
        fi
      fi
      dest="''${1:-''${host:-workstation}}" # an ssh Host of ~/.ssh/config, or `local` for a drop on this machine

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
      # VS Code's terminal paste, aimed at the window the key was pressed in, not the active one.
      if [ -n "$vscode" ]; then
        hyprctl dispatch "hl.dsp.send_shortcut({ mods = \"CTRL SHIFT\", key = \"code:55\", window = \"address:$vscode\" })" >/dev/null || true
      fi
      note "$dest: $dir/$name"
    '';
  };
in
{
  home.packages = [ clipboardPush ];
}
