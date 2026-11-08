# ChatGPT: OpenAI's official Linux app (ChatGPT plus Codex) on the newest .deb (pkgs/chatgpt), kept
# for Codex; daily chats are my.webApps.chatgpt. Why both: docs/notes/apps/chatgpt.md
{ pkgs, ... }:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    codex
    unstable # the CHANNEL and not a package, so `unstable.x` stays greppable at each use site
    ;
in
{
  # The SAME Codex CLI as modules/home/shell/codex.nix (pkgs/codex), not unstable's older one:
  # the wrapper points CODEX_CLI_PATH at it, so the app and the terminal never drift apart.
  home.packages = [ (unstable.chatgpt.override { inherit codex; }) ];
}
