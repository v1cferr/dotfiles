# 0013. The site's graph view takes one dependency

The map of docs/ at `/graph` is drawn by `react-force-graph-2d`, the first library the visual layer
added to the lockfile.

- **Status**: accepted, refines [0010](0010-visual-layer-without-component-library.md)
- **Date**: 13/10/2026

## Context

[0010](0010-visual-layer-without-component-library.md) built the visual layer from what the bundle
already carried, and deferred the Graph View with a stated trigger: "a measured Graph View that
stays readable at 114 pages". On 13/10/2026 the request came back explicitly, and the tree had 127
pages and 350 links between them, read off the markdown at build time. A note here is rarely read
alone, and the links are the one structure the sidebar cannot show.

A force layout is a physics simulation (repulsion, link springs, collision) plus a canvas renderer
with zoom, pan and hit testing. Written by hand it would be the largest piece of code in the site,
and the one most likely to be subtly wrong.

## Decision

Take `react-force-graph-2d` 1.29.2 (MIT), pinned exactly, and nothing else:

| Option | Verdict |
| --- | --- |
| `react-force-graph-2d` | **chosen**: canvas, d3-force underneath, the library Fumadocs' own Graph View recipe uses |
| a hand-written SVG simulation | rejected: a physics engine to maintain for one page |
| Fumadocs' Graph View component as copied in | rejected: the same library, plus a copy of code to keep in sync |
| no graph | rejected: the trigger in 0010 was met |

0010 still holds for everything else: the diagram viewer added the same week was written on a
native `<dialog>` and pointer events, with no dependency.

## Consequences

- MEASURED on 13/10/2026: the library is ONE chunk of 41 KiB gzipped, loaded by `/graph` alone
  through a dynamic import; not one other page's HTML references it, and the up-front JS of a
  page did not move because of it.
- The lockfile and the `pnpmDeps` hash moved, so rule 13's pin covers it like any other package.
  `pnpm audit` found nothing in its tree; the advisories it reports today are all in `next`,
  `mermaid` and `sharp`, which were there before.
- The graph's data is built from the markdown at BUILD time (`tools/docs-site/lib/graph.ts`), so
  a page or a link added to `docs/` appears on the map with no step of its own.
- **The trigger to revisit**: the library going unmaintained, or the page count growing until the
  map stops being readable even with the section filter and the search.
