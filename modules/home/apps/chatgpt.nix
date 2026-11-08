# ChatGPT: OpenAI's official Linux app (ChatGPT plus Codex), unstable's recipe on the newest .deb
# (pkgs/chatgpt), and a tabbed web launcher for daily chats. Why both: docs/notes/apps/chatgpt.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    codex
    coreutils
    unstable # the CHANNEL and not a package, so `unstable.x` stays greppable at each use site
    writeShellApplication
    ;

  # Its own profile: tabs, session restore and the login stay apart from everyday browsing.
  profile = "${config.xdg.dataHome}/chatgpt-web";

  # The guarded Zen (rule 11). `--name` is the Wayland app_id: vault.lua's `chatgpt` pattern hides
  # it on lock like the app, and it never matches `^zen`.
  web = writeShellApplication {
    name = "chatgpt-web";
    runtimeInputs = [ coreutils ];
    text = ''
      mkdir -p ${lib.escapeShellArg profile}
      exec ${lib.getExe' config.my.zen.package "zen-beta"} --profile ${lib.escapeShellArg profile} \
        --name chatgpt-web "''${@:-https://chatgpt.com}"
    '';
  };
in
{
  # The SAME Codex CLI as modules/home/shell/codex.nix (pkgs/codex), not unstable's older one:
  # the wrapper points CODEX_CLI_PATH at it, so the app and the terminal never drift apart.
  home.packages = [
    (unstable.chatgpt.override { inherit codex; })
    web
  ];

  xdg.desktopEntries.chatgpt-web = {
    name = "ChatGPT (tabs)";
    comment = "chatgpt.com with tabs, on a dedicated Zen profile";
    exec = "${lib.getExe web} %U";
    icon = "chatgpt";
    categories = [ "Network" ];
  };
}
