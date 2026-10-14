# Vicinae script commands: my existing CLIs as searchable entries, each a checked writeShellApplication.
# The header format and how to add one: docs/notes/desktop/vicinae.md
{
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  inherit (pkgs) util-linux writeShellApplication xdg-utils;

  repo = osConfig.programs.nh.flake;

  # The @vicinae header is plain comments under the shebang, so shellcheck still sees a script.
  # The commands are called by name, as keybinds.lua does: their modules own the derivations.
  mkScript =
    {
      name,
      title,
      group,
      mode ? "silent",
      confirm ? false,
      text,
    }:
    writeShellApplication {
      inherit name;
      runtimeInputs = [
        util-linux # setsid, so a GUI child outlives the script
        xdg-utils
      ];
      text = ''
        # @vicinae.schemaVersion 1
        # @vicinae.title ${title}
        # @vicinae.mode ${mode}
        # @vicinae.packageName ${group}
        ${lib.optionalString confirm "# @vicinae.needsConfirmation true"}
        ${text}
      '';
    };

  openUrl = name: title: url: {
    inherit name title;
    group = "Links";
    text = "xdg-open ${lib.escapeShellArg url}";
  };

  scripts = map mkScript [
    {
      name = "vpn-fai";
      title = "Connect FAI VPN";
      group = "VPN";
      mode = "compact";
      text = "vpn connect fai";
    }
    {
      name = "vpn-ufscar";
      title = "Connect UFSCar VPN";
      group = "VPN";
      mode = "compact";
      text = "vpn connect ufscar";
    }
    {
      name = "vpn-disconnect";
      title = "Disconnect VPN";
      group = "VPN";
      mode = "compact";
      text = "vpn disconnect all";
    }
    {
      name = "ssh-workstation";
      title = "SSH: FAI workstation";
      group = "Desktop";
      text = "setsid -f kitty ssh workstation";
    }
    {
      name = "restart-quickshell";
      title = "Restart Quickshell";
      group = "Desktop";
      text = "qs-restart";
    }
    {
      name = "shuffle-wallpapers";
      title = "Shuffle wallpapers";
      group = "Desktop";
      text = "wallpaper-shuffle both";
    }
    {
      name = "lock-session";
      title = "Lock session";
      group = "Desktop";
      text = "loginctl lock-session";
    }
    {
      name = "keybinds";
      title = "Show keybind cheatsheet";
      group = "Desktop";
      # Detached, so the cheatsheet's dmenu opens after this command's window has closed.
      text = "setsid -f keybinds-cheatsheet";
    }
    {
      # A visible terminal: nh's sudo prompt and the build log stay in front of me.
      name = "nixos-rebuild";
      title = "NixOS rebuild (switch)";
      group = "System";
      confirm = true;
      text = "setsid -f kitty --hold --title 'NixOS rebuild' zsh -ic rebuild";
    }
    {
      name = "dotfiles-code";
      title = "Open dotfiles in VS Code";
      group = "Links";
      text = "setsid -f code ${lib.escapeShellArg repo}";
    }
    (openUrl "fai-dashboard" "Open FAI Dashboard" "https://dashboard.sup.fai.ufscar.br")
    (openUrl "github" "Open GitHub" "https://github.com/v1cferr")
    (openUrl "dotfiles-github" "Open dotfiles on GitHub" "https://github.com/v1cferr/dotfiles")
  ];
in
{
  # One link per script in the default scripts dir, which Vicinae scans and watches.
  xdg.dataFile = lib.listToAttrs (
    map (s: lib.nameValuePair "vicinae/scripts/${s.name}" { source = lib.getExe s; }) scripts
  );
}
