# docs-site: it builds docs/ into the static site served at dotfiles.v1cferr.dev.
# Why MkDocs, why the tree did not move, and the two manual halves: docs/notes/repo/site.md
{
  lib,
  stdenvNoCC,
  python3,
}:

let
  # Both on ONE interpreter, which is what puts `mkdocs` on PATH with the theme importable.
  mkdocsEnv = python3.withPackages (ps: [
    ps.mkdocs
    ps.mkdocs-material
  ]);
in
stdenvNoCC.mkDerivation {
  pname = "docs-site";
  version = "0";

  # ONLY what the site is built from, so a commit touching system/ does not rebuild it.
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../docs
      ../mkdocs.yml
      ../scripts/mkdocs-hooks.py
    ];
  };

  nativeBuildInputs = [ mkdocsEnv ];

  dontBuild = true;

  # --strict is the whole point: it turns the nav and link validation in mkdocs.yml from a report
  # nobody reads into a build failure. HOME because mkdocs writes a cache directory.
  installPhase = ''
    runHook preInstall
    export HOME=$TMPDIR
    mkdocs build --strict --site-dir $out
    runHook postInstall
  '';

  dontFixup = true;

  # The devShell reuses THIS env for `mkdocs serve`, so the preview and the build are
  # one definition and cannot drift apart (rule 11).
  passthru.env = mkdocsEnv;

  meta = {
    description = "The docs/ tree of this repo, built into a static site";
    homepage = "https://dotfiles.v1cferr.dev/";
    platforms = lib.platforms.all;
  };
}
