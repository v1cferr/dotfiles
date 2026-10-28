# PERSISTENCE: what in ~ survives a boot once impermanence lands. NOT active yet: a list plus `persist-diff`.
# The model (user folders whole, app state by name) and how to turn it on: docs/notes/boot-and-storage/impermanence.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    coreutils
    findutils
    gawk
    gnugrep
    util-linux
    writeShellApplication
    writeText
    ;

  cfg = config.my.persist;

  # The same entry shapes nix-community/impermanence takes (`"path"` or `{ directory; mode; }`),
  # so turning it on is wiring this list in, not rewriting it.
  entry = lib.types.either lib.types.str (lib.types.attrsOf lib.types.str);
  pathOf = e: if builtins.isString e then e else e.directory or e.file;
  paths = map pathOf (cfg.directories ++ cfg.files);

  # Every parent of a persisted path: persist-diff descends into these instead of reporting them.
  ancestors = lib.unique (
    lib.concatMap (
      p:
      let
        parts = lib.splitString "/" p;
      in
      map (n: lib.concatStringsSep "/" (lib.take n parts)) (lib.range 1 (lib.length parts - 1))
    ) paths
  );

  persistDiff = writeShellApplication {
    name = "persist-diff";
    runtimeInputs = [
      coreutils
      findutils
      gawk
      gnugrep
      util-linux
    ];
    text = ''
      # What in ~ is NOT on the list, so it would be gone after the next boot with impermanence on.
      persisted=${writeText "persisted" (lib.concatLines paths)}
      ancestors=${writeText "ancestors" (lib.concatLines ancestors)}
      out="$(mktemp)"
      trap 'rm -f "$out"' EXIT

      walk() {
        local dir="$1" f rel
        while IFS= read -r -d "" f; do
          rel="''${f#"$HOME"/}"
          grep -qxF -- "$rel" "$persisted" && continue
          if grep -qxF -- "$rel" "$ancestors"; then
            walk "$f"
            continue
          fi
          mountpoint -q "$f" && continue # rclone mounts come back with their unit
          # home-manager output comes back on every switch: a store link, or a folder of only those.
          if [ -L "$f" ] && [[ "$(readlink "$f")" == /nix/store/* ]]; then continue; fi
          if [ -d "$f" ] && [ ! -L "$f" ] &&
            [ -z "$(find "$f" ! -type d ! -lname '/nix/store/*' -print -quit 2>/dev/null)" ]; then
            continue
          fi
          printf '%s\t%s\n' "$(du -s --block-size=1 -- "$f" 2>/dev/null | cut -f1)" "$rel" >> "$out"
        done < <(find "$dir" -mindepth 1 -maxdepth 1 -print0)
      }

      walk "$HOME"
      sort -rn "$out" | numfmt --field=1 --to=iec --suffix=B --padding=7
      echo "$(awk -F'\t' '{s += $1} END {print s + 0}' "$out" | numfmt --to=iec --suffix=B) in $(wc -l < "$out") paths would not survive a boot"
    '';
  };
in
{
  options.my.persist = {
    directories = lib.mkOption {
      type = lib.types.listOf entry;
      description = "Folders under ~ kept across boots (impermanence's users.<name>.directories).";
    };
    files = lib.mkOption {
      type = lib.types.listOf entry;
      description = "Single files under ~ kept across boots (impermanence's users.<name>.files).";
    };
  };

  config = {
    my.persist = {
      directories = [
        # The user folders, whole: what is in them is mine to organize, not this list's.
        "Desktop"
        "Documents"
        "Downloads"
        "Music"
        "Pictures"
        "Videos"
        "Projects"
        "Games" # games installed outside Steam/Bottles
        "Archive" # the old Arch restic repo, mounted by arch-legacy-mount
        "CS2-Saves-Backup" # cs2-saves-backup writes here
        ".dropbox-hm" # the Dropbox data (Obsidian vault); ~/Dropbox is a link the service recreates
        ".dropbox" # the Dropbox account link, or it asks to relink

        # Keys and credentials.
        {
          directory = ".ssh";
          mode = "0700";
        }
        {
          directory = ".gnupg";
          mode = "0700";
        }
        {
          directory = ".local/share/keyrings";
          mode = "0700";
        }
        ".local/state/keyring" # the TPM-sealed keyring password (keyring-tpm-seal)
        ".config/rclone" # Drive, VPS and FAI-workstation remotes, with their tokens
        ".config/gh" # the GitHub CLI token
        ".config/Bitwarden CLI"
        ".config/immich" # immich-go's server key
        ".local/share/rbw" # the Bitwarden CLI's device registration
        ".config/atuin" # the sync key (the config itself is a store link inside)
        ".local/share/com.vercel.cli" # login
        ".config/.wrangler" # Cloudflare login
        ".docker" # registry logins
        ".azure"
        ".cloudflared"
        ".android" # adb keys already paired with the phone
        ".pki" # the user's NSS certificate store
        ".stackwallet" # a crypto wallet: kept until its seed is confirmed elsewhere
        ".local/share/Bisq2" # Bisq trade keys

        # Games: the biggest and most expensive state to lose.
        ".local/share/bottles" # the Wine prefixes, with saves
        ".local/share/Steam"
        ".steam" # links into the folder above, plus the Steam runtime
        ".local/share/PrismLauncher" # Minecraft instances and worlds
        ".local/share/Larian Studios"
        ".local/state/Larian Studios"
        ".local/share/wenilla-rogue"
        ".config/CurseForge"
        ".local/share/applications" # launchers Steam and Bottles create for games
        ".local/share/icons" # their icons

        # Browsers.
        ".zen"
        ".mozilla"
        ".config/mozilla"
        ".config/google-chrome-unstable"
        ".config/librewolf"

        # AI tools: sessions, memory, logins.
        ".claude"
        ".claude-fai"
        ".claude-pessoal"
        ".claude-presence" # claude-discord-rpc's state next to its declared config
        ".config/Claude" # the desktop app
        ".codex"
        ".gemini" # agy reads it
        ".basic-memory"
        ".ollama" # the client key; the models live in the system service

        # Apps whose state is not declared here.
        ".vscode" # extensions come from Settings Sync, not from Nix
        ".config/Code"
        ".config/discord"
        ".config/obsidian"
        ".config/OpenRGB" # the saved RGB profiles
        ".config/org.coolercontrol.CoolerControl"
        ".local/share/org.coolercontrol.CoolerControl"
        ".config/sunshine" # paired clients
        ".config/Moonlight Game Streaming Project" # paired hosts
        ".config/syncthing" # device identity
        ".config/qBittorrent"
        ".local/share/qBittorrent"
        ".config/spotifast"
        ".local/share/spotifast"
        ".local/state/spotifast"
        ".local/state/soloist" # the Spotify session; re-pairing only works from the phone
        ".config/zapfast"
        ".local/share/zapfast"
        ".local/state/zapfast"
        ".config/vicinae"
        ".local/share/vicinae" # the clipboard history
        ".local/state/vicinae"
        ".local/share/vicinae-reminders"
        ".local/state/vicinae-reminders"
        ".local/share/opencode"
        ".local/state/opencode"
        ".config/opencode" # mixed: the config is a store link, the rest is its state
        ".local/share/TelegramDesktop"
        ".local/share/onlyoffice"
        ".local/share/org.localsend.localsend_app"
        ".config/freerdp" # the t480 certificate
        ".local/share/direnv" # the allowed .envrc list
        ".local/share/atuin" # shell history
        ".local/share/zoxide"
        ".local/share/qalculate" # calculator history
        ".local/share/caddy" # the local dev CA
        ".config/dconf" # the GSettings database GTK apps write to
        ".local/share/dolphin"
        ".local/share/gwenview"
        ".local/state/wireplumber" # default audio devices and volumes
        ".local/state/lockscreen"
        ".local/state/quickshell"
        ".local/state/signalsift"
        ".local/state/credit-radar"
        ".local/state/disk-insight" # the size trend log
        ".local/state/claude-checks"
        ".local/state/context"
        ".local/share/Trash" # the trash stays recoverable until trash-expire empties it
      ];

      files = [
        ".claude.json"
        ".zsh_history"
        ".google_authenticator" # the PAM TOTP secret
        ".config/dolphinrc"
        ".config/gwenviewrc"
        ".config/arkrc"
        ".config/kdeglobals"
        ".config/pavucontrol.ini"
        ".local/share/user-places.xbel" # Dolphin's sidebar places
      ];
    };

    home.packages = [ persistDiff ];
  };
}
