# docs-site-check: `mkdocs build --strict` into a throwaway directory, so a page left out of the
# nav fails at the PUSH and not later in the CI (rule 20): docs/notes/repo/site.md
{
  writeShellApplication,
  docs-site,
}:

writeShellApplication {
  name = "docs-site-check";

  # The env comes FROM the site derivation, so the check and the build are the same mkdocs.
  runtimeInputs = [ docs-site.env ];

  text = ''
    site=$(mktemp -d)
    trap 'rm -rf "$site"' EXIT
    mkdocs build --strict --site-dir "$site/out"
  '';
}
