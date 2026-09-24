// THE URL MODEL, and the ONE owner of it: the loader, the link rewriter, the nav gate and the
// export check all read this file, so a slug rule cannot drift: docs/notes/repo/site.md

/** The extensions a page is written in. */
export const PAGE_EXTENSION = /\.mdx?$/;

/** A README is the page of the folder holding it, which is what makes /guides/ a page. */
export const INDEX_FILE = /^(README|index)\.mdx?$/;

/** `notes/repo/site.md` becomes `['notes','repo','site']`, `guides/README.md` becomes `['guides']`. */
export function docSlugs(path: string): string[] {
  const segments = path.split('/').filter(Boolean);
  const name = segments.pop()!;
  if (!INDEX_FILE.test(name)) segments.push(name.replace(PAGE_EXTENSION, ''));
  return segments;
}

/**
 * The published URL of a page, with NO trailing slash: that is the form Fumadocs normalizes to
 * before matching a route against the page tree, and the breadcrumb goes silent without it.
 * The slash a reader sees comes back from `trailingSlash` in next.config.mjs, which is also what
 * writes `/notes/repo/site/index.html` instead of `/notes/repo/site.html`.
 */
export function docUrl(slugs: string[]): string {
  return slugs.length === 0 ? '/' : '/' + slugs.join('/');
}

/** Both halves at once, for a path relative to docs/. */
export function docPathToUrl(path: string): string {
  return docUrl(docSlugs(path));
}

/**
 * The URL as a reader SEES it, with the slash `trailingSlash` puts back. Anything that states an
 * address instead of linking to one needs this form: the canonical tag and the sitemap.
 */
export function servedUrl(url: string): string {
  return url.endsWith('/') ? url : `${url}/`;
}
