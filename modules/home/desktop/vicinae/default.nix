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
  inherit (pkgs) writeText;

  p = config.my.theme.palette;
  c = name: "#${p.${name}}";
  home = config.home.homeDirectory;

  # Declared settings ride VICINAE_OVERRIDES: merged over settings.json, which stays writable for
  # the GUI (programs.vicinae.settings would make it a read-only store link).
  overrides = writeText "vicinae-overrides.json" (
    builtins.toJSON {
      telemetry.system_info = false;
      favicon_service = "none"; # no third-party favicon lookups
      input_server.enabled = false; # no uinput helper: select copies, nothing types for me
      tray.enabled = false; # Quickshell's tray has no use for it
      close_on_focus_loss = true;
      pop_to_root_on_close = true;
      search_files_in_root = true;
      escape_key_behavior = "close_window";
      encrypt_sensitive_data = true; # off by default on Linux; the key lives in the keyring
      font.normal.family = osConfig.my.fonts.ui;
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
        client_side_decorations.border_width = 2;
      };
      favorites = [ "clipboard:history" ];
      fallbacks = [ "files:search" ];
      providers = {
        calculator.preferences.backend = "qalculate";
        clipboard.preferences = {
          monitoring = true;
          ignorePasswords = true; # drops x-kde-passwordManagerHint offers (KeePassXC, Bitwarden)
          preserveTagged = true; # pinned and tagged entries survive the eviction
          evictionThreshold = "2592000"; # 30 days
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
  ];

  programs.vicinae = {
    enable = true;
    package = pkgs.unstable.vicinae; # 0.29 against 26.05's 0.23
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
          border = c "border";
          accent = c "accent";
          accent_foreground = c "bg";
        };
        main_window.border = c "accent";
        settings_window.border = c "border";
        accents = {
          blue = c "blue";
          green = c "green";
          magenta = c "magenta";
          orange = c "orange";
          purple = c "purple";
          red = c "red";
          yellow = c "yellow";
          cyan = c "cyan";
        };
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
          border = c "border";
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
  systemd.user.services.vicinae = {
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
