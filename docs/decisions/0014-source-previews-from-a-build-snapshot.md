# 0014. The site previews source from a snapshot built beside it

A page of the site shows the repo files it is about, in a tree, and opens them highlighted in place.
The files come from a snapshot built at the same commit, under a publication policy, and never from
GitHub at read time.

- **Status**: accepted, refines [0005](0005-fumadocs-for-the-site.md) and
  [0010](0010-visual-layer-without-component-library.md)
- **Date**: 17/10/2026

## Context

A note here explains a module, and the module lives outside `docs/`. The site turned 140 links to
it into GitHub blob URLs, so reading the implementation meant leaving the page, and a page that
cites a module's folder, or names files in backticks, gave no way in at all. The request was to read
the source next to the prose, with the tree of the files involved.

Three constraints shaped the answer before any option was weighed. The site is static on Pages,
with no backend. [Rule 20](../rules.md#20-the-docs-are-a-product) forbids the reader's browser from
fetching anything from a third party. And `docs-site` keeps its src fenced to `docs/`, so a module
commit does not rebuild the site.

## Decision

A second derivation, `docs-sources`, indexes which files each page is about and copies those files,
and `pages` joins it to the site, as it already joins the stats:

| Option | Verdict |
| --- | --- |
| a snapshot built beside the site, joined in `pages` | **chosen**: static, same commit, the site's fence intact |
| the snapshot inside `docs-site` | rejected: every `modules/` commit would rebuild the site |
| GitHub's API or an embed in the browser | rejected: a third party at read time, against rule 20 |
| copying the whole repo into the export | rejected: it publishes what no page shows |

What may be published is ONE file, `tools/docs-site/source-policy.json`: roots, languages, and what
is kept out by path, by name and by content. Both the Nix fence and the indexer read it.

The browser half takes no dependency, as 0010 asks: the right column is Fumadocs' documented TOC
slot, the code is Fumadocs' own code block on shiki's core, and the drawer is a native `<dialog>`.
The indexer imports four markdown packages that were already in the lockfile under Fumadocs.

## Consequences

- The site now republishes repo files. The policy is the boundary, and it is conservative: it keeps
  out `secrets/`, the router's mirror, anything named like a secret or a lockfile, and FAILS the
  build on a credential's shape in a publishable file.
- The index and the HTML come from two derivations, so `check-sources.ts` proves at the join that
  every section id the index cites exists on the page. A change in Fumadocs' heading slugger shows
  up there and not as a silently dead highlight.
- MEASURED on 17/10/2026: the JS a page loads up front grew by 8.5 KiB gzipped, the first preview
  fetches 64.4 KiB more, and the export gained 27 chunk files and 1.5 MiB of sources. The detail
  and the rest of the numbers: [site-sources](../notes/repo/site-sources.md).
- **The trigger to revisit**: the published output outgrowing what Pages serves comfortably, or a
  page needing a file the policy cannot publish often enough that the GitHub fallback stops being
  enough.
