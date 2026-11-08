# WEB APPS on Zen: one launcher and one profile per `engine = "zen"` entry of my.webApps
# (modules/nixos/desktop/web-apps.nix, the SSOT). Why: docs/notes/apps/web-apps.md
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs) coreutils writeShellApplication;

  onZen = lib.filterAttrs (_: a: a.engine == "zen") osConfig.my.webApps;

  # `<name>-web` is the command, the profile directory AND the Wayland app_id (`--name`), so
  # vault.lua's patterns can key on the app's name without matching `^zen`.
  launcher =
    name: app:
    let
      id = "${name}-web";
      profile = "${config.xdg.dataHome}/${id}";
    in
    writeShellApplication {
      name = id;
      runtimeInputs = [ coreutils ];
      text = ''
        mkdir -p ${lib.escapeShellArg profile}
        exec ${lib.getExe' config.my.zen.package "zen-beta"} --profile ${lib.escapeShellArg profile} \
          --name ${id} "''${@:-${app.url}}"
      '';
    };

  launchers = lib.mapAttrs launcher onZen;
in
{
  home.packages = lib.attrValues launchers;

  xdg.desktopEntries = lib.mapAttrs' (
    name: app:
    lib.nameValuePair "${name}-web" {
      name = app.label;
      comment = "${app.url} on a dedicated Zen profile";
      exec = "${lib.getExe launchers.${name}} %U";
      inherit (app) icon;
      categories = [ "Network" ];
    }
  ) onZen;
}
