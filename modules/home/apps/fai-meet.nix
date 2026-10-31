# FAI MEET, the user side (the package is pkgs/fai-meet/package.nix): the FAI's meeting recorder.
# Why the scheme is declared here and not by the app: docs/notes/apps/fai-meet.md
{ pkgs, lib, ... }:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs) curl jq;
in
{
  home.packages = [ pkgs.fai-meet ]; # the official AppImage, repackaged (./pkgs), unfree

  # Merges with the associations from xdg.nix and media.nix. The app's own xdg-mime call cannot
  # write the store-managed mimeapps.list, so without this the login comes back to nothing.
  xdg.mimeApps.defaultApplications."x-scheme-handler/fai-meet" = "fai-meet.desktop";

  # The source build at the commit `just publicar-nix` last published, so it always comes from the
  # FAI's cache (modules/nixos/core/core.nix). Never the main branch: unpublished commits compile.
  programs.zsh.siteFunctions.fai-meet-latest = ''
    local rev
    rev=$(${lib.getExe curl} -fsS https://meet.sup.fai.ufscar.br/v1/desktop/latest | ${lib.getExe jq} -er .nix.rev) || return
    nix run "git+ssh://git@git.sup.fai.ufscar.br:2222/ia/plataforma/fai-meetings?rev=$rev#fai-meet" -- "$@"
  '';
}
