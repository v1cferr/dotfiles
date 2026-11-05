# vendored-bump: runs every vendored package's passthru.updateScript in parallel; any failure fails the run.
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

  # All bumps run AT ONCE: each one writes only its own source.json, and the run costs the slowest
  # upstream instead of the sum of all of them. Each output is buffered and printed in order, and
  # any failure still fails the run, after every bump has had its turn.
  text = ''
    repo="''${1:?usage: vendored-bump <path-to-the-flake-repo>}"
    logs=$(mktemp -d)
    trap 'rm -rf "$logs"' EXIT
    pids=()
  ''
  + lib.concatStrings (
    lib.mapAttrsToList (name: p: ''
      ${exe name p} "$repo" >"$logs/${name}" 2>&1 &
      pids+=("$!")
    '') packages
  )
  + ''
    failed=0
    for pid in "''${pids[@]}"; do wait "$pid" || failed=1; done
    cat "$logs"/*
    exit "$failed"
  '';

  meta = {
    description = "Runs every vendored package's updateScript against the flake repo";
    mainProgram = "vendored-bump";
  };
}
