// THE URL MODEL, and the ONE owner of it: the loader, the link rewriter and the export check all
// read this file, so a slug rule cannot drift between them. Why these URLs: docs/notes/repo/site.md

/** The extensions a page is written in. A README is the page of the folder holding it. */
export const PAGE_EXTENSION = /\.mdx?$/;
const INDEX_NAMES = new Set(['README', 'index']);

/** `notes/repo/site.md` becomes `['notes','repo','site']`, `guides/README.md` becomes `['guides']`. */
export function docSlugs(path: string): string[] {
  const segments = path.split('/').filter(Boolean);
  const name = segments.pop()!.replace(PAGE_EXTENSION, '');
  if (!INDEX_NAMES.has(name)) segments.push(name);
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
