// THE TITLE IS THE H1, and that is the whole rule: no page in docs/ carries frontmatter, because
// a `title:` next to the heading would be a second owner of one string (rule 14).
const FENCE = /^\s*(```|~~~)/;
const H1 = /^#\s+(.+?)\s*$/;

/** The first H1 of a markdown document, skipping anything a fenced example only shows. */
export function titleFromMarkdown(source: string): string | undefined {
  let fenced = false;
  for (const line of source.split('\n')) {
    if (FENCE.test(line)) {
      fenced = !fenced;
      continue;
    }
    if (fenced) continue;

    const heading = H1.exec(line);
    if (heading) return heading[1];
  }
}
