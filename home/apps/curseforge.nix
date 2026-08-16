# CURSEFORGE, the user side (the package is pkgs/curseforge.nix). It replaced prismlauncher and
# SHRANK the closure by 1.5 GiB. The schemes are not optional: docs/notes/curseforge.md
{ pkgs, lib, ... }:

let
  curseforge = "curseforge.desktop";
in
{
  home.packages = [
    pkgs.curseforge # the official AppImage, repackaged (./pkgs), unfree
    # Recomputes version+hash of pkgs/curseforge.nix. On the PATH because the `update` alias calls
    # it by name, the same arrangement as vscode-bump.
    pkgs.curseforge-bump
    # Gives back the `+x` on what the app unpacks. On the PATH because the breaking download can
    # happen mid-session, when the activation below has already run.
    pkgs.curseforge-fix-perms
  ];

  # An IDEMPOTENT activation and not managed files: the APP owns what it unpacks (rule 14), so
  # Nix only undoes known damage. writeBoundary, since the package has to be in the profile.
  home.activation.curseforgeFixPerms = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe pkgs.curseforge-fix-perms}
  '';

  # Merges with the associations from xdg.nix and media.nix. cfauth is the LOGIN callback.
  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/cfauth" = curseforge; # the login callback, the one that matters most
    "x-scheme-handler/curseforge" = curseforge; # the "Install" button on the modpack site
    "x-scheme-handler/curseforge-checkout" = curseforge; # buying a premium add-on
  };
}
