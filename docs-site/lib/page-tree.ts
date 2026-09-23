// THE GATE: it turns lib/navigation.ts into the sidebar, and REFUSES to build when that list and
// docs/ disagree. It is what `mkdocs build --strict` used to be: docs/notes/repo/site.md
//
// A hand-written nav is a second owner of the page list (rule 14), and the build is what keeps it
// honest, the same trade rule 7 makes for shell scripts. It earned that once already: a page was
// written, indexed and left out of the nav, with only this class of check to say so.
import type * as PageTree from 'fumadocs-core/page-tree';
import { type NavItem, type NavPage, type NavSection, navigation } from './navigation.ts';
import { source } from './source.ts';
import { docSlugs } from './urls.ts';

const INDEX_FILE = /(^|\/)(README|index)\.mdx?$/;

function isSection(item: NavItem): item is NavSection {
  return 'section' in item;
}

class NavigationError extends Error {
  constructor(problems: string[]) {
    super(`the nav and docs/ disagree:\n\n${problems.map((p) => `  ${p}`).join('\n')}\n`);
    this.name = 'NavigationError';
  }
}

/** One walk: it builds the tree and collects every problem, so one build reports them all. */
function build(items: NavItem[], seen: Map<string, string>, problems: string[]) {
  const nodes: PageTree.Node[] = [];

  for (const item of items) {
    if (isSection(item)) {
      const children = build(item.items, seen, problems);
      // A README with no title of its own is the section's page, which is what
      // `navigation.indexes` gave the nav in MkDocs.
      const first = item.items[0];
      const leadsWithIndex =
        first !== undefined && !isSection(first) && first.title === undefined && INDEX_FILE.test(first.doc);

      nodes.push({
        type: 'folder',
        name: item.section,
        index: leadsWithIndex ? (children.shift() as PageTree.Item) : undefined,
        children,
      });
      continue;
    }

    const node = page(item, seen, problems);
    if (node) nodes.push(node);
  }

  return nodes;
}

function page(item: NavPage, seen: Map<string, string>, problems: string[]): PageTree.Item | undefined {
  const found = source.getPage(docSlugs(item.doc));
  if (!found) {
    problems.push(`nav entry "${item.doc}" has no such page under docs/`);
    return;
  }

  const duplicate = seen.get(found.url);
  if (duplicate !== undefined) {
    problems.push(`"${item.doc}" and "${duplicate}" both land on ${found.url}`);
    return;
  }
  seen.set(found.url, item.doc);

  return { type: 'page', name: item.title ?? found.data.title, url: found.url };
}

function pageTree(): PageTree.Root {
  const problems: string[] = [];
  const seen = new Map<string, string>();
  const children = build(navigation, seen, problems);

  // The half no hand-written nav catches on its own: a page that exists and nothing points at.
  for (const found of source.getPages()) {
    if (!seen.has(found.url)) problems.push(`docs/${found.path} is not in the nav`);
  }

  if (problems.length > 0) throw new NavigationError(problems.toSorted());
  return { name: 'dotfiles', children };
}

export const tree = pageTree();
