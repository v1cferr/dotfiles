# 0005. The site is built with Fumadocs

- **Status**: accepted
- **Date**: 23/09/2026; it supersedes [0004](0004-mkdocs-for-the-site.md)

## Context

The trigger 0004 recorded fired: MkDocs was frozen upstream. The candidate named on the day,
Zensical, was still `0.0.x` with a release every two days, which is the churn rule 13 keeps out,
and the one hook this site depends on (the links rewritten to their source) had no documented
place in it.

## Decision

[Fumadocs](https://fumadocs.dev/) on Next.js, as a static export: `output: 'export'` writes plain
files, and Next.js is a build-time tool pinned in `flake.lock` that never runs where a reader can
reach it.

## Consequences

- The three extension points the old setup reached for through a hook are documented APIs here:
  the URL of a page, the page tree of the nav, and a remark pipeline for the link rewriting.
- A Node toolchain now builds the site, made hermetic in Nix.
- **It cost one directory**: the tree never moved to match the generator (rule 20), so the 92
  markdown files did not change by one byte. The reasoning in full is in
  [site](../notes/repo/site.md).
