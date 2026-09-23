// remark-repo-links: it makes the repo's own links work on a site that only serves docs/.
//
// A page links to the module it documents (`../../../system/services/caddy.nix`), and 140 of those
// targets sit outside docs/, where the site has nothing to serve. This resolves every relative
// target against the page's own directory, the same rule `docs-links` applies, and the ones that
// escape docs/ become blob URLs on GitHub. The markdown on disk is never touched, so the same link
// keeps working when the file is read there.
//
// It replaces the MkDocs hook that did this, and what was rejected: docs/notes/repo/site.md
import path from 'node:path';
import type { Link, Root } from 'mdast';
import { visit } from 'unist-util-visit';
import type { VFile } from 'vfile';
import { BLOB_BASE, TREE_BASE } from '../lib/repo.ts';
import { PAGE_EXTENSION, docPathToUrl } from '../lib/urls.ts';

const EXTERNAL = ['http://', 'https://', 'mailto:', '#', '/'];

export interface RepoLinksOptions {
  /** Absolute path of docs/, so a target can be told from one that escapes it. */
  root: string;
  /** Directories under docs/ that own an index page, so a `history/` link lands on a page. */
  indexed: Set<string>;
}

/** The target of one link, rewritten. `undefined` means leave it exactly as written. */
function rewrite(source: string, target: string, options: RepoLinksOptions): string | undefined {
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
    if (!escapes && options.indexed.has(inside)) return folderUrl(inside) + anchor;
    return `${TREE_BASE}/${repoRelative}`;
  }

  if (escapes) return `${BLOB_BASE}/${repoRelative}${anchor}`;
  // Inside docs/, but not a page: nothing renders it, so GitHub serves the file itself.
  if (!PAGE_EXTENSION.test(file)) return `${BLOB_BASE}/${repoRelative}${anchor}`;
  return docPathToUrl(inside) + anchor;
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
  return folder === '' ? '/' : `/${folder}/`;
}

export function remarkRepoLinks(options: RepoLinksOptions) {
  return (tree: Root, file: VFile) => {
    // Relative to docs/, which is what every target in a page is resolved against.
    const source = path.posix.relative(options.root, file.path ?? '');

    visit(tree, 'link', (node: Link) => {
      const next = rewrite(source, node.url, options);
      if (next !== undefined) node.url = next;
    });
  };
}
