# docs-sources: the snapshot the site's source previews read, built BESIDE the site and joined in
# `pages`, so a modules/ commit does not rebuild the site: docs/notes/repo/site-sources.md
{
  lib,
  stdenvNoCC,
  docs-site,
  pnpmConfigHook,
}:

let
  repo = ../..;
  # The roots and the extensions are READ from the policy, so this fence and the indexer cannot
  # disagree (rule 11). A file outside it never enters the sandbox, so it cannot be published.
  policy = lib.importJSON ./source-policy.json;
  extensions = lib.attrNames policy.extensions;
  eligible = lib.fileset.unions (
    map (
      root:
      let
        at = repo + "/${root}";
      in
      if lib.pathIsDirectory at then
        lib.fileset.fileFilter (file: lib.any file.hasExt extensions) at
      else
        lib.fileset.maybeMissing at
    ) policy.roots
  );
in
stdenvNoCC.mkDerivation {
  pname = "docs-sources";
  version = "0";

  # docs/, the eligible files, and the app files the indexer imports. What a dev tree builds is
  # subtracted by name, `maybeMissing` because a fresh clone has none of it.
  src = lib.fileset.toSource {
    root = repo;
    fileset =
      lib.fileset.difference
        (lib.fileset.unions [
          ../../docs
          eligible
          ./package.json
          ./pnpm-lock.yaml
          ./source-policy.json
          ./lib
          ./scripts
          ./tests
        ])
        (
          lib.fileset.unions (
            map lib.fileset.maybeMissing [
              ./node_modules
              ./.next
              ./.source
              ./out
              ./public
            ]
          )
        );
  };

  nativeBuildInputs = [
    docs-site.nodejs
    docs-site.pnpm
    pnpmConfigHook
  ];

  # The SAME fixed-output store as the site: one lockfile, one fetch, one hash to bump.
  inherit (docs-site) pnpmDeps;
  pnpmRoot = "tools/docs-site";

  buildPhase = ''
    runHook preBuild
    node tools/docs-site/scripts/build-sources.ts _source "$PWD"
    runHook postBuild
  '';

  # The indexer's tests run on every build, so `nix flake check` is what runs them.
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    node --test 'tools/docs-site/tests/*.test.ts'
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    cp -r _source $out
    runHook postInstall
  '';

  dontFixup = true;

  meta = {
    description = "The repo files the docs site previews, with the page-to-file index";
    homepage = "https://dotfiles.v1cferr.dev/";
    platforms = lib.platforms.all;
  };
}
