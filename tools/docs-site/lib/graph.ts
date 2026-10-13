// THE GRAPH: every page of docs/ and the links between them, read at BUILD time from the markdown
// itself, so the map cannot disagree with the pages it draws: docs/notes/repo/site.md
import fs from 'node:fs';
import path from 'node:path';
import { DOCS_ROOT } from './docs-root.ts';
import { type NavItem, navigation } from './navigation.ts';
import { listPages } from './page-tree.ts';
import { prose, titleFromMarkdown } from './summary.ts';
import { PAGE_EXTENSION, docPathToUrl } from './urls.ts';

/** Where the graph is published: the page and the export check both read it. */
export const GRAPH_URL = '/graph';

export interface GraphNode {
  id: string; // the page's URL
  title: string;
  group: string; // the top-level nav section, or "Overview" for a page outside every section
  degree: number; // links in plus links out, which sizes the dot
}

export interface GraphLink {
  source: string;
  target: string;
}

const OVERVIEW = 'Overview';
// A markdown link, `[text](target)`, with the target up to the first space or parenthesis.
const LINK = /\]\(([^)\s]+)\)/g;

/** The nav's top-level section of each page, and the nav's own title when it gives one. */
function sections(items: NavItem[], group = OVERVIEW, found = new Map<string, [string, string?]>()) {
  for (const item of items) {
    if ('section' in item) sections(item.items, group === OVERVIEW ? item.section : group, found);
    else found.set(item.doc, [group, item.title]);
  }
  return found;
}

/** A relative link of `page`, resolved to another page of docs/, or undefined. */
function resolve(page: string, target: string, pages: Set<string>): string | undefined {
  if (/^[a-z]+:|^[#/]/i.test(target)) return;
  const file = target.split('#')[0]!;
  if (!file) return;
  const joined = path.posix.normalize(path.posix.join(path.posix.dirname(page), file));
  if (joined.startsWith('..')) return;
  // A folder link lands on the folder's README, as the link rewriter makes it.
  const candidate = file.endsWith('/') ? path.posix.join(joined, 'README.md') : joined;
  if (PAGE_EXTENSION.test(candidate) && pages.has(candidate)) return candidate;
}

export function buildGraph(): { nodes: GraphNode[]; links: GraphLink[]; groups: string[] } {
  const list = listPages(DOCS_ROOT);
  const pages = new Set(list);
  const nav = sections(navigation);
  const nodes = new Map<string, GraphNode>();
  const links = new Map<string, GraphLink>();

  for (const page of list) {
    const source = fs.readFileSync(path.join(DOCS_ROOT, page), 'utf8');
    const [group, navTitle] = nav.get(page) ?? [OVERVIEW];
    const id = docPathToUrl(page);
    nodes.set(id, { id, title: navTitle ?? titleFromMarkdown(source) ?? page, group, degree: 0 });

    for (const line of prose(source)) {
      for (const [, target] of line.matchAll(LINK)) {
        const to = resolve(page, target!, pages);
        if (!to) continue;
        const other = docPathToUrl(to);
        // Undirected and deduplicated: two pages citing each other are ONE line on the map.
        const key = [id, other].toSorted().join(' ');
        if (other !== id && !links.has(key)) links.set(key, { source: id, target: other });
      }
    }
  }

  for (const { source, target } of links.values()) {
    nodes.get(source)!.degree++;
    nodes.get(target)!.degree++;
  }

  // The order the sidebar shows them, so the legend reads like the nav.
  const groups = [OVERVIEW, ...navigation.flatMap((item) => ('section' in item ? [item.section] : []))];
  return { nodes: [...nodes.values()], links: [...links.values()], groups };
}
