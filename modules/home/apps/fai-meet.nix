# FAI MEET, on demand only: the FAI's meeting recorder, never part of the system closure.
# Why it is not installed: docs/notes/apps/fai-meet.md
{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs) curl jq;

  # The cache is declared once, as a trusted substituter in modules/nixos/core/core.nix (rule 11).
  cache = lib.head osConfig.nix.settings.extra-trusted-substituters;
in
{
  # The source build at the commit `just publicar-nix` last published, so it always comes from the
  # FAI's cache, asked for HERE and nowhere else. Never the main branch: unpublished commits compile.
  programs.zsh.siteFunctions.fai-meet-latest = ''
    local rev
    rev=$(${lib.getExe curl} -fsS https://meet.sup.fai.ufscar.br/v1/desktop/latest | ${lib.getExe jq} -er .nix.rev) || return
    nix run --option extra-substituters ${cache} "git+ssh://git@git.sup.fai.ufscar.br:2222/ia/plataforma/fai-meetings?rev=$rev#fai-meet" -- "$@"
  '';
}
