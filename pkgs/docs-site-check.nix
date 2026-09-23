# docs-site-check: it fails when a page of docs/ is left out of the nav, so that lands at the
# COMMIT and not later in the CI (rule 20): docs/notes/repo/site.md
{
  writeShellApplication,
  docs-site,
  git,
}:

writeShellApplication {
  name = "docs-site-check";

  # The node comes FROM the site derivation, so the gate and the build run the same runtime.
  runtimeInputs = [
    docs-site.nodejs
    git
  ];

  # It reads docs/ and one TypeScript file, with NO node_modules: that is what turns the old
  # 7.12s site build into a check cheap enough to charge every commit for.
  text = ''
    root=$(git rev-parse --show-toplevel)
    node "$root/docs-site/scripts/check-navigation.ts"
  '';
}
