# BASIC MEMORY (`bm`): the MCP memory server, built from the uv.lock in ./basic-memory.
# Why uv2nix, and what the two build-system fixes are: docs/notes/apps/basic-memory.md
{
  lib,
  callPackage,
  python313,
  inputs,
}:

let
  # OUR workspace, not upstream's: a pyproject declaring ONE dependency, so the lock next to it is
  # the pin (rule 13) and the version bump is a `uv lock` away.
  workspace = inputs.uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./basic-memory; };

  # Wheels over sdists: the lock hashes both, and this way nothing here compiles from source.
  overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };

  # Two sdists that never declared setuptools as a build dependency, which uv refuses to guess.
  fixBuildSystems =
    final: prev:
    lib.genAttrs [ "pybars3" "pymeta3" ] (
      name:
      prev.${name}.overrideAttrs (old: {
        nativeBuildInputs =
          (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; };
      })
    );

  # 3.13 and not `python3`: the lock resolves `requires-python = "==3.13.*"`, so the interpreter
  # is part of the pin.
  pythonSet =
    (callPackage inputs.pyproject-nix.build.packages { python = python313; }).overrideScope
      (
        lib.composeManyExtensions [
          inputs.pyproject-build-systems.overlays.default
          overlay
          fixBuildSystems
        ]
      );
in
(pythonSet.mkVirtualEnv "basic-memory-env" workspace.deps.default).overrideAttrs (old: {
  meta = (old.meta or { }) // {
    description = "Local-first knowledge base over Markdown files, served to AI agents over MCP";
    homepage = "https://github.com/basicmachines-co/basic-memory";
    license = lib.licenses.agpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "bm";
  };
})
