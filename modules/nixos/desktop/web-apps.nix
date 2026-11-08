# WEB APPS (SSOT): sites lighter than their vendor's app; Chrome's via policy, Zen's from
# modules/home/apps/web-apps.nix. Why web apps and why two engines: docs/notes/apps/web-apps.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  apps = config.my.webApps;
  onChrome = lib.filterAttrs (_: a: a.engine == "chrome") apps;
in
{
  options.my.webApps = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            url = lib.mkOption {
              type = lib.types.str;
              description = "The site the app opens.";
            };
            engine = lib.mkOption {
              type = lib.types.enum [
                "chrome"
                "zen"
              ];
              description = ''
                "chrome": an installed PWA in the signed-in Chrome profile (shared login, one window per
                app, app_id chrome-<id>-Default). "zen": the guarded Zen on a profile of its own (tabs,
                a separate login, app_id <name>-web).
              '';
            };
            label = lib.mkOption {
              type = lib.types.str;
              default = name;
              description = "Launcher name for a Zen app (Chrome names its own from the manifest).";
            };
            icon = lib.mkOption {
              type = lib.types.str;
              default = "applications-internet";
              description = "Icon name or absolute path for a Zen app's launcher (Chrome fetches its own).";
            };
          };
        }
      )
    );
    default = { };
    description = "The web apps, by name (SSOT). Read by modules/home/ through osConfig.";
  };

  config = {
    my.webApps = {
      # Google ships the desktop app for Windows and macOS only (docs/notes/apps/gemini.md).
      gemini = {
        url = "https://gemini.google.com/app";
        engine = "chrome";
      };
      # Zen for the TABS the official app lacks; Codex is the CLI (docs/notes/apps/chatgpt.md).
      chatgpt = {
        url = "https://chatgpt.com";
        engine = "zen";
        label = "ChatGPT";
        # The icon theme has none; homarr-labs/dashboard-icons (Apache-2.0), pinned by commit.
        icon = "${pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/59f1e9a4108f4f510f41e9588f078631de1e1405/svg/chatgpt.svg";
          hash = "sha256-Wo2tKGTMHIEJ6650vqRH3y8wuXi9rVZ0kkfEBuHLIic=";
        }}";
      };
    };

    # Merged with the spellcheck keys into the same /etc/opt/chrome/policies JSON. Chrome applies it
    # only while running; dropping an entry uninstalls the app at its next policy refresh.
    programs.chromium.extraOpts.WebAppInstallForceList = lib.mapAttrsToList (_: a: {
      inherit (a) url;
      default_launch_container = "window";
      create_desktop_shortcut = false; # the launcher entry is enough; nothing on a desktop
    }) onChrome;
  };
}
