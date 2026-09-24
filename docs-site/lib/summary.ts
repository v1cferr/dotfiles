// THE TITLE AND THE DESCRIPTION ARE THE PAGE ITSELF: the H1 and the first paragraph. No page in
// docs/ carries frontmatter, because a `title:` or a `description:` next to the prose that already
// says it would be a second owner of one string (rule 14): docs/notes/repo/site.md
const FENCE = /^\s*(```|~~~)/;
const H1 = /^#\s+(.+?)\s*$/;
const HEADING = /^#{1,6}\s/;
// What a search result and a social card have room for before a reader stops reading.
const MAX_DESCRIPTION = 160;

/** Lines that are PROSE: a fenced example is not, and neither is a heading. */
function* prose(source: string): Generator<string> {
  let fenced = false;
  for (const line of source.split('\n')) {
    if (FENCE.test(line)) {
      fenced = !fenced;
      continue;
    }
    if (!fenced) yield line;
  }
}

/** The first H1 of a markdown document. */
export function titleFromMarkdown(source: string): string | undefined {
  for (const line of prose(source)) {
    const heading = H1.exec(line);
    if (heading) return heading[1];
  }
}

/** The first paragraph after the title, flattened to one sentence of plain text. */
export function descriptionFromMarkdown(source: string): string | undefined {
  const paragraph: string[] = [];
  let seenTitle = false;

  for (const line of prose(source)) {
    if (!seenTitle) {
      seenTitle = H1.test(line);
      continue;
    }
    // The paragraph ends at the blank line after it; anything before it is still the gap.
    if (line.trim() === '') {
      if (paragraph.length > 0) break;
      continue;
    }
    // A list, a table or another heading is not a summary of the page.
    if (HEADING.test(line) || /^\s*([-*+>|]|\d+\.)\s/.test(line)) break;
    paragraph.push(line.trim());
  }

  if (paragraph.length === 0) return;
  return truncate(plain(paragraph.join(' ')));
}

/** Markdown inline syntax removed, so the text reads as a sentence outside a renderer. */
function plain(text: string): string {
  return text
    .replace(/!\[([^\]]*)\]\([^)]*\)/g, '$1') // an image, down to its alt text
    .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1') // a link, down to its label
    .replace(/<([^>\s]+)>/g, '$1') // an autolink
    .replace(/[`*_]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Cut at a word boundary, because half a word reads as a bug. */
function truncate(text: string): string {
  if (text.length <= MAX_DESCRIPTION) return text;
  const cut = text.slice(0, MAX_DESCRIPTION);
  const space = cut.lastIndexOf(' ');
  return `${(space > 0 ? cut.slice(0, space) : cut).replace(/[,.;:]$/, '')}...`;
}
