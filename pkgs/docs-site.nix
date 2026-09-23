# docs-site: it builds docs/ into the static site served at dotfiles.v1cferr.dev (rule 20).
# Why Fumadocs, and how a Node toolchain stays hermetic here: docs/notes/repo/site.md
{
  lib,
  stdenvNoCC,
  nodejs_24,
  pnpm_10,
}:

let
  # The MAJOR is pinned and not taken from the `pnpm` alias: the store format changes between
  # majors, and the fetcher and the build have to agree on one.
  pnpm = pnpm_10;

  # What the DEPENDENCIES are resolved from, and nothing else: a page edit must not invalidate
  # the fetch, which is the one step of this build that needs the network.
  manifest = lib.fileset.toSource {
    root = ../docs-site;
    fileset = lib.fileset.unions [
      ../docs-site/package.json
      ../docs-site/pnpm-lock.yaml
    ];
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "docs-site";
  version = "0";

  # ONLY what the site is built from, so a commit touching system/ does not rebuild it. The build
  # outputs are subtracted by name: `maybeMissing` because a fresh clone has none of them.
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../docs
      (lib.fileset.difference ../docs-site (
        lib.fileset.unions (
          map lib.fileset.maybeMissing [
            ../docs-site/node_modules
            ../docs-site/.next
            ../docs-site/.source
            ../docs-site/out
            ../docs-site/next-env.d.ts
          ]
        )
      ))
    ];
  };

  nativeBuildInputs = [
    nodejs_24
    pnpm.configHook
  ];

  # The node_modules of the lockfile, fetched ONCE as a fixed-output derivation. Bump the hash in
  # the same commit as the lockfile, or the build resolves yesterday's tree (rule 13).
  pnpmDeps = pnpm.fetchDeps {
    inherit (finalAttrs) pname version;
    src = manifest;
    fetcherVersion = 3;
    hash = "sha256-snrVW3R/CFchPbHqNW9NSBiL9bwWFBKeiZ3bsr9CXuA=";
  };
  # Relative to the source root: the app is a subdirectory, because docs/ is its sibling.
  pnpmRoot = "docs-site";

  # NO network from here on. The telemetry ping is the one thing Next.js would still try.
  env.NEXT_TELEMETRY_DISABLED = "1";

  buildPhase = ''
    runHook preBuild
    pnpm --dir docs-site build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cp -r docs-site/out $out
    runHook postInstall
  '';

  dontFixup = true;

  # The devShell and the nav gate reuse THESE, so the preview, the check and the build are one
  # definition and cannot drift apart (rule 11).
  passthru = {
    nodejs = nodejs_24;
    inherit pnpm;
  };

  meta = {
    description = "The docs/ tree of this repo, built into a static site";
    homepage = "https://dotfiles.v1cferr.dev/";
    platforms = lib.platforms.all;
  };
})
