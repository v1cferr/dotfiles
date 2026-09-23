// The search INDEX, written into the static build as a file the browser downloads once. There is
// no server behind it, which is the only kind of search Pages can host: docs/notes/repo/site.md
import { createSearchAPI } from 'fumadocs-core/search/server';
import { source } from '../../../lib/source.ts';

export const revalidate = false;

export const { staticGET: GET } = createSearchAPI('advanced', {
  language: 'english',
  // SORTED, and this is reproducibility and not taste: the loader hands back the pages in the
  // order a parallel build happened to compile them, and the index numbers its documents from
  // that order. `nix build --rebuild` is what caught it.
  indexes: source
    .getPages()
    .toSorted((a, b) => (a.url < b.url ? -1 : 1))
    .map((page) => ({
      id: page.url,
      url: page.url,
      title: page.data.title,
      description: page.data.description,
      structuredData: page.data.structuredData,
    })),
});
