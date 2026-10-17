// remark-repo-links: it makes the repo's own links work on a site that only serves docs/.
//
// A page links to the module it documents (`../../../modules/nixos/services/caddy.nix`), and 140 of those
// targets sit outside docs/, where the site has nothing to serve. This resolves every relative
// target against the page's own directory, the same rule `docs-links` applies, and the ones that
// escape docs/ become blob URLs on GitHub. The markdown on disk is never touched, so the same link
// keeps working when the file is read there.
//
// It replaces the MkDocs hook that did this, and what was rejected: docs/notes/repo/site.md
//
// It also MARKS what the source preview may take over: a blob link carries the repo path it points
// at, and an inline code span shaped like a path carries its text. Marking is all it does, since
// the site is built without the repo files; the page's manifest decides, in the browser, which of
// them are real. No mark changes a link's href: docs/notes/repo/site-sources.md
import path from 'node:path';
import type { InlineCode, Link, Nodes, Root } from 'mdast';
import { visit } from 'unist-util-visit';
import type { VFile } from 'vfile';
import { BLOB_BASE, TREE_BASE } from '../lib/repo.ts';
import { isSourceToken, lineFromAnchor } from '../lib/source-manifest.ts';
import { normalizeRepoPath } from '../lib/source-policy.ts';
import { PAGE_EXTENSION, docPathToUrl, docUrl } from '../lib/urls.ts';

const EXTERNAL = ['http://', 'https://', 'mailto:', '#', '/'];

export interface RepoLinksOptions {
  /** Absolute path of docs/, so a target can be told from one that escapes it. */
  root: string;
  /** Directories under docs/ that own an index page, so a `history/` link lands on a page. */
  indexed: Set<string>;
}

/** A rewritten target, and the repo FILE it is a blob of, when it is one. */
interface Rewritten {
  url: string;
  file?: string;
}

/** The target of one link, rewritten. `undefined` means leave it exactly as written. */
function rewrite(source: string, target: string, options: RepoLinksOptions): Rewritten | undefined {
  if (EXTERNAL.some((prefix) => target.startsWith(prefix))) return;

  const [file, anchor] = splitAnchor(target);
  if (!file) return;

  const here = path.posix.dirname(source);
  // Relative to docs/. A result starting with `..` is a file the site does not serve.
  const inside = normalize(path.posix.join(here, file));
  const repoRelative = normalize(path.posix.join('docs', here, file));
  const escapes = inside.startsWith('..');

  // A link to a FOLDER: it gets that folder's page when there is one, and GitHub's tree listing
  // when there is not, because a static site has no folder to render.
  if (file.endsWith('/')) {
    if (!escapes && options.indexed.has(inside)) return { url: folderUrl(inside) + anchor };
    return { url: `${TREE_BASE}/${repoRelative}` };
  }

  // Inside docs/ but not a page, nothing renders it either, so GitHub serves the file itself.
  if (escapes || !PAGE_EXTENSION.test(file)) {
    return { url: `${BLOB_BASE}/${repoRelative}${anchor}`, file: repoRelative };
  }
  return { url: docPathToUrl(inside) + anchor };
}

function splitAnchor(target: string): [string, string] {
  const hash = target.indexOf('#');
  return hash === -1 ? [target, ''] : [target.slice(0, hash), target.slice(hash)];
}

/** Node keeps the trailing slash that Python's normpath drops, and the folder key has none. */
function normalize(target: string): string {
  const normalized = path.posix.normalize(target).replace(/\/+$/, '');
  return normalized === '.' ? '' : normalized;
}

function folderUrl(folder: string): string {
  return docUrl(folder === '' ? [] : folder.split('/'));
}

/** Attributes for the HTML element a node becomes, which is how a mark reaches the MDX component. */
function mark(node: Nodes, properties: Record<string, string>) {
  node.data ??= {};
  node.data.hProperties = { ...node.data.hProperties, ...properties };
}

export function remarkRepoLinks(options: RepoLinksOptions) {
  return (tree: Root, file: VFile) => {
    // Relative to docs/, which is what every target in a page is resolved against.
    const source = path.posix.relative(options.root, file.path ?? '');
    // A code span that already sits inside an anchor (a link's text, a heading, which the theme
    // wraps in its own `#id` link) cannot become a link itself: nested anchors are invalid HTML.
    const anchored = new Set<InlineCode>();

    visit(tree, 'link', (node: Link) => {
      visit(node, 'inlineCode', (code: InlineCode) => void anchored.add(code));
      const next = rewrite(source, node.url, options);
      if (next === undefined) return;
      node.url = next.url;
      // The ONE canonical spelling, or no mark: a path that is not one is never offered a preview.
      if (next.file !== undefined && normalizeRepoPath(next.file) === next.file) {
        const hash = node.url.indexOf('#');
        const line = hash === -1 ? undefined : lineFromAnchor(node.url.slice(hash));
        mark(node, { 'data-source-path': next.file, ...(line && { 'data-source-line': String(line) }) });
      }
    });
    visit(tree, 'heading', (node) => {
      visit(node, 'inlineCode', (code: InlineCode) => void anchored.add(code));
    });

    visit(tree, 'inlineCode', (node: InlineCode) => {
      if (!anchored.has(node) && isSourceToken(node.value)) mark(node, { 'data-source-ref': node.value });
    });
  };
}
