# docs-site: it builds docs/ into the static site served at dotfiles.v1cferr.dev.
# Why MkDocs, why the tree did not move, and the two manual halves: docs/notes/repo/site.md
{
  lib,
  stdenvNoCC,
  python3,
  fetchurl,
}:

let
  # Mermaid VENDORED, pinned to an exact version and a hash. Material's theme otherwise pulls
  # `unpkg.com/mermaid@11` at page load, which is rule 13's moving pointer in the reader's browser.
  # mermaid-cli was the obvious source and was measured at 2.1 GiB of closure: it drags chromium.
  # fetchurl and not fetchzip: this hash is the TARBALL's, which `sha256sum` and npm's own
  # integrity field both reproduce, instead of a NAR hash only Nix can check.
  mermaid = fetchurl {
    url = "https://registry.npmjs.org/mermaid/-/mermaid-11.12.0.tgz";
    hash = "sha256-k0kuTWCb6DZTpBxDX0y9fnRBn3+mtPyQqMmDGV9kr4I=";
  };

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
      ../overrides
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
    # AFTER the build: the override references this path, and mkdocs validates nothing a
    # template emits, so the file never has to sit inside docs/ or in git.
    mkdir -p $out/assets/javascripts
    tar -xzOf ${mermaid} package/dist/mermaid.min.js > $out/assets/javascripts/mermaid.min.js
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
