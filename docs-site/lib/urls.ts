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

/** The published URL of a page. The trailing slash is what MkDocs served and Pages still expects. */
export function docUrl(slugs: string[]): string {
  return '/' + slugs.map((segment) => segment + '/').join('');
}

/** Both halves at once, for a path relative to docs/. */
export function docPathToUrl(path: string): string {
  return docUrl(docSlugs(path));
}
