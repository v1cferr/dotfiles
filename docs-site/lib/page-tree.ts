// THE GATE: it turns lib/navigation.ts into the sidebar, and REFUSES to build when that list and
// docs/ disagree. It is what `mkdocs build --strict` used to be: docs/notes/repo/site.md
//
// A hand-written nav is a second owner of the page list (rule 14), and the build is what keeps it
// honest, the same trade rule 7 makes for shell scripts. It earned that once already: a page was
// written, indexed and left out of the nav, with only this class of check to say so.
//
// It reads docs/ with node:fs and NOTHING else, so the pre-push hook can run it on bare node,
// with no bundler and no node_modules: one definition, two consumers.
import fs from 'node:fs';
import path from 'node:path';
import type * as PageTree from 'fumadocs-core/page-tree';
import { type NavItem, type NavPage, type NavSection, navigation } from './navigation.ts';
import { titleFromMarkdown } from './summary.ts';
import { INDEX_FILE, PAGE_EXTENSION, docPathToUrl } from './urls.ts';

/** Every page of docs/, as a path relative to it. */
export function listPages(docsRoot: string, prefix = ''): string[] {
  const found: string[] = [];
  for (const entry of fs.readdirSync(path.join(docsRoot, prefix), { withFileTypes: true })) {
    const rel = path.posix.join(prefix, entry.name);
    if (entry.isDirectory()) found.push(...listPages(docsRoot, rel));
    else if (PAGE_EXTENSION.test(entry.name)) found.push(rel);
  }
  return found;
}

function isSection(item: NavItem): item is NavSection {
  return 'section' in item;
}

interface Walk {
  docsRoot: string;
  pages: Set<string>;
  seen: Map<string, string>;
  problems: string[];
}

function pageNode(item: NavPage, walk: Walk): PageTree.Item | undefined {
  if (!walk.pages.has(item.doc)) {
    walk.problems.push(`nav entry "${item.doc}" has no such page under docs/`);
    return;
  }

  const url = docPathToUrl(item.doc);
  const duplicate = walk.seen.get(url);
  if (duplicate !== undefined) {
    walk.problems.push(`"${item.doc}" and "${duplicate}" both land on ${url}`);
    return;
  }
  walk.seen.set(url, item.doc);

  // No title in the nav means the page names itself, and the H1 is where that name lives.
  const name =
    item.title ?? titleFromMarkdown(fs.readFileSync(path.join(walk.docsRoot, item.doc), 'utf8'));
  if (name === undefined) {
    walk.problems.push(`"${item.doc}" has no H1, so nothing names it`);
    return;
  }

  return { type: 'page', name, url };
}

/** One walk: it builds the nodes and collects every problem, so one build reports them all. */
function build(items: NavItem[], walk: Walk): PageTree.Node[] {
  const nodes: PageTree.Node[] = [];

  for (const item of items) {
    if (!isSection(item)) {
      const node = pageNode(item, walk);
      if (node) nodes.push(node);
      continue;
    }

    const children = build(item.items, walk);
    // A README with no title of its own is the section's page, which is what
    // `navigation.indexes` gave the nav in MkDocs.
    const first = item.items[0];
    const leadsWithIndex =
      first !== undefined &&
      !isSection(first) &&
      first.title === undefined &&
      INDEX_FILE.test(path.posix.basename(first.doc));

    nodes.push({
      type: 'folder',
      name: item.section,
      index: leadsWithIndex ? (children.shift() as PageTree.Item) : undefined,
      children,
    });
  }

  return nodes;
}

export function buildPageTree(docsRoot: string): PageTree.Root {
  const walk: Walk = {
    docsRoot,
    pages: new Set(listPages(docsRoot)),
    seen: new Map(),
    problems: [],
  };
  const children = build(navigation, walk);

  // The half no hand-written nav catches on its own: a page that exists and nothing points at.
  for (const page of walk.pages) {
    if (!walk.seen.has(docPathToUrl(page))) walk.problems.push(`docs/${page} is not in the nav`);
  }

  if (walk.problems.length > 0) {
    const listed = walk.problems.toSorted().map((problem) => `  ${problem}`);
    throw new Error(`the nav and docs/ disagree:\n\n${listed.join('\n')}\n`);
  }

  return { name: 'dotfiles', children };
}
