# 0010. The site's visual layer adds no component library

The diagrams, steps and overview the docs needed are built from what the site already bundled, and nothing was added to the lockfile.

- **Status**: accepted
- **Date**: 01/10/2026; it refines [0005](0005-fumadocs-for-the-site.md)

## Context

The site rendered the markdown faithfully and stopped there. A note like
[network](../notes/network/network.md) is a long run of sections, each about one arrow of a
topology the reader had to assemble alone, and the home was a table. The request was a visual
layer in the style of a developer portal: diagrams, flows, steps, an overview, and charts.

## Decision

Build it from the three pieces already in the bundle, and add nothing:

| Need | Built from | Instead of |
| --- | --- | --- |
| diagrams and flows | Mermaid fences in `docs/`, themed from the Fumadocs preset's own tokens | a second renderer such as beautiful-mermaid |
| a procedure | Fumadocs' `remarkSteps`, over the numbered headings of `guides/` | a Steps component written into the markdown |
| an overview | Fumadocs' `Card` and `buttonVariants`, filled from the page tree | shadcn/ui, copied in through `components.json` |
| icons | `lucide-react`, which Fumadocs UI already depends on | a second icon set |

shadcn/ui lost for the reason [site](../notes/repo/site.md) gave on 23/09/2026, which still holds:
Fumadocs UI already brings every piece of the docs shell, and a second component library is
maintenance bought for nothing. Recharts (through shadcn's Chart) and the Fumadocs Graph View
were NOT adopted either, and that is a deferral, not a verdict: no page has a number to chart yet,
and the graph was not measured. Both were reasoned about, not tried.

## Consequences

- The lockfile did not move, so rule 13 and the fetch hash held with no work.
- Every diagram is a fence in `docs/`, so GitHub draws it too, and nothing visual lives in JSX.
- MEASURED on 01/10/2026 against the build before it: the JS a page loads up front grew by 0.3
  KiB gzipped (370.6 to 370.9), and a page's HTML by about 2.3 KB gzipped, the sidebar's icons.
- **The trigger to revisit**: a page with quantitative data worth a chart (the `/stats` that
  `tools/repo-stats` renders is the candidate), or a measured Graph View that stays readable at
  114 pages.
