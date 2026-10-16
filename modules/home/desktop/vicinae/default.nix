# VICINAE: the launcher (SUPER+Q), clipboard history and command palette, themed from the palette.
# Why it replaced rofi and cliphist, and every setting: docs/notes/desktop/vicinae.md
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  inherit (pkgs)
    app2unit
    ffmpegthumbnailer
    poppler-utils
    pulseaudio
    writeText
    ;

  p = config.my.theme.palette;
  c = name: "#${p.${name}}";
  home = config.home.homeDirectory;

  # Declared settings ride VICINAE_OVERRIDES: merged over settings.json, which stays writable for
  # the GUI (programs.vicinae.settings would make it a read-only store link).
  overrides = writeText "vicinae-overrides.json" (
    builtins.toJSON {
      telemetry.system_info = false;
      favicon_service = "google"; # tab and shortcut icons: only the host leaves, once, then a disk cache
      input_server.enabled = false; # no uinput helper: select copies, nothing types for me
      tray.enabled = false; # Quickshell's tray has no use for it
      # Hyprland hands it a focus-out right after it maps, so this closed it within 92 ms (measured).
      close_on_focus_loss = false;
      pop_to_root_on_close = true;
      search_files_in_root = true;
      escape_key_behavior = "close_window";
      encrypt_sensitive_data = true; # off by default on Linux; the key lives in the keyring
      font.normal = {
        family = osConfig.my.fonts.ui;
        size = 11.5;
      };
      # Both slots, so a light portal preference never swaps in Vicinae's stock theme.
      theme = rec {
        dark = {
          name = "palette";
          icon_theme = config.my.theme.iconTheme;
        };
        light = dark;
      };
      launcher_window = {
        # exclusive grabs the keyboard and breaks popup mouse handling on Hyprland
        layer_shell.keyboard_interactivity = "on_demand";
        client_side_decorations.border_width = 1;
        size = {
          width = 1000;
          height = 620;
        };
      };
      favorites = [
        "clipboard:history"
        "@v1cferr/repositories:repositories"
        "@ShyAssassin/vscode-recents:open-recents"
      ];
      inherit (config.my.vicinae) fallbacks;
      providers = {
        # Aliases: typing one ranks its command first, above any score, so "rep" + Enter opens it.
        scripts.entrypoints.dotfiles-code.alias = "dot";
        "@v1cferr/repositories".entrypoints.repositories.alias = "rep";
        "@ShyAssassin/vscode-recents".entrypoints.open-recents.alias = "rec";
        "@rastsislaux/pulseaudio".entrypoints.outputDevices.alias = "vol";
        # Each app in its own app-*.scope under app.slice, not in vicinae.service's cgroup.
        applications.preferences.launchPrefix = "${lib.getExe app2unit} --";
        calculator.preferences.backend = "qalculate";
        clipboard.preferences = {
          monitoring = true;
          ignorePasswords = true; # drops x-kde-passwordManagerHint offers (KeePassXC, Bitwarden)
          preserveTagged = true; # pinned and tagged entries survive the eviction
          evictionThreshold = "2592000"; # 30 days
        };
        # The local Repositories extension (./repositories): these accounts in this order, then FAI's
        # GitLab. Its GitHub token rides the sops render below; the GitLab one is read from its file.
        "@v1cferr/repositories".preferences = {
          githubOwners = lib.concatStringsSep "," [
            "v1cferr"
            "victor-ferreira-fai-ufscar" # the FAI account
            "drakko2002" # my brother's
          ];
          gitlabUrl = "https://git.sup.fai.ufscar.br"; # only through the FAI VPN
          gitlabTitle = "FAI GitLab";
          gitlabTokenFile = osConfig.sops.secrets.fai_gitlab_token.path or "";
        };
        # Named folders only, so dotfiles (keys, browser profiles, caches) never reach the index.
        files.preferences.indexingPaths = map (d: "${home}/${d}") [
          "Desktop"
          "Documents"
          "Downloads"
          "Pictures"
          "Music"
          "Videos"
          "Projects"
          "Archive"
        ];
      };
    }
  );

  # The GitHub extension's token: a sops-nix render in /run/secrets, never the store (rule 12).
  # It exists only once the token is in the vault (modules/nixos/core/secrets.nix).
  githubToken = osConfig.sops.templates."vicinae-github.json".path or null;
in
{
  imports = [
    ./extensions.nix
    ./scripts.nix
    ./shortcuts.nix
  ];

  # What the root search offers when nothing matches, in order (shortcuts.nix puts its own first).
  options.my.vicinae.fallbacks = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Vicinae fallback entrypoints, as provider:id.";
  };

  config.my.vicinae.fallbacks = lib.mkAfter [ "files:search" ];

  config.programs.vicinae = {
    enable = true;
    # 0.29 against 26.05's 0.23, patched so built-in icons are bare line glyphs (no accent tile),
    # like the Nerd Font script icons. --replace-fail breaks the build if upstream moves the line.
    # Also patched with a Linux backend for its FileThumbnail images (macOS-only upstream), so the
    # file search previews PDFs and videos through the shared ~/.cache/thumbnails. The built-in
    # volume commands look pactl up on PATH, where it is not; pinned (PipeWire answers it).
    package = pkgs.unstable.vicinae.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./file-thumbnails.patch ];
      postPatch = (old.postPatch or "") + ''
        substituteInPlace src/server/src/ui/image/image-stream.cpp \
          --replace-fail "if (c.isValid() && c.alpha() > 0) return c;" ""
        substituteInPlace src/server/src/ui/image/xdg-file-thumbnail-loader.cpp \
          --replace-fail '"ffmpegthumbnailer";' '"${lib.getExe ffmpegthumbnailer}";' \
          --replace-fail '"pdftoppm";' '"${lib.getExe' poppler-utils "pdftoppm"}";'
        substituteInPlace src/server/src/services/audio-control/pactl/pactl-audio-control.cpp \
          --replace-fail 'QStandardPaths::findExecutable("pactl").toStdString()' '"${lib.getExe' pulseaudio "pactl"}"'
      '';
    });
    systemd = {
      enable = true;
      target = "graphical-session.target";
    };

    # The palette mapped onto Vicinae's theme schema; selection and focus follow the accent.
    themes.palette = {
      meta = {
        version = 1;
        name = "Palette (${config.my.theme.name})";
        description = "Generated from my.theme.palette";
        variant = "dark";
        inherits = "vicinae-dark";
      };
      colors = {
        core = {
          background = c "bg";
          foreground = c "text";
          secondary_background = c "surface";
          border = c "track"; # the dividers: a step above the surface, barely there
          accent = c "accent";
          accent_foreground = c "bg";
        };
        # A 1 px outline at half strength frames it without the accent ring it used to have.
        main_window.border = {
          name = c "border";
          opacity = 0.5;
        };
        settings_window.border = c "border";
        # Full strength: they color alerts, syntax, script ANSI output and tags (the tiles are patched out).
        accents = lib.genAttrs [
          "blue"
          "green"
          "magenta"
          "orange"
          "purple"
          "red"
          "yellow"
          "cyan"
        ] c;
        text = {
          default = c "text";
          muted = c "subtext";
          placeholder = c "dim";
          danger = c "red";
          success = c "green";
          selection = {
            background = c "accent";
            foreground = c "bg";
          };
          links = {
            default = c "blue";
            visited = c "purple";
          };
        };
        input = {
          border = c "track";
          border_focus = c "accent";
          border_error = c "red";
        };
        list.item = {
          hover.foreground = c "text";
          selection = {
            background = c "track";
            foreground = c "text";
            secondary_background = c "track";
            secondary_foreground = c "accent";
          };
        };
        grid.item = {
          background = c "surface";
          hover.outline = c "subtext";
          selection.outline = c "accent";
        };
        scrollbars.background = c "track";
        loading = {
          bar = c "accent";
          spinner = c "text";
        };
      };
    };
  };

  # The HM unit plus the repo's session conventions (polkit-agent.nix) and the overrides.
  config.systemd.user.services.vicinae = {
    Unit = {
      ConditionEnvironment = "WAYLAND_DISPLAY";
      X-Restart-Triggers = [ "${overrides}" ];
    };
    Service = {
      Environment = [
        "VICINAE_OVERRIDES=${overrides}${lib.optionalString (githubToken != null) ":${githubToken}"}"
      ];
      Slice = "session.slice";
      TimeoutStopSec = 5;
    };
  };
}
