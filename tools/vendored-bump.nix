# vendored-bump: runs every vendored package's passthru.updateScript, stopping at the first failure.
# Why the list is derived and each script goes by store path: docs/notes/repo/version-bumps.md
{
  lib,
  writeShellApplication,
  packages,
}:

let
  # Only the derivation form: the list or attrset forms of nixpkgs would be skipped in silence.
  exe =
    name: p:
    if lib.isDerivation p.updateScript then
      lib.getExe p.updateScript
    else
      throw "vendored-bump: ${name}'s updateScript is not a derivation (set it to null to opt out)";
in
writeShellApplication {
  name = "vendored-bump";

  # set -euo pipefail already comes from writeShellApplication, so a failed bump ends the run.
  text = ''
    repo="''${1:?usage: vendored-bump <path-to-the-flake-repo>}"
  ''
  + lib.concatStrings (
    lib.mapAttrsToList (name: p: ''
      ${exe name p} "$repo"
    '') packages
  );

  meta = {
    description = "Runs every vendored package's updateScript against the flake repo";
    mainProgram = "vendored-bump";
  };
}
