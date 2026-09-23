// The nav gate on BARE NODE: no bundler, no node_modules, so `pkgs/docs-site-check.nix` can run
// it at pre-push in milliseconds instead of building the whole site: docs/notes/repo/site.md
import path from 'node:path';
import { buildPageTree, listPages } from '../lib/page-tree.ts';

const docsRoot = path.resolve(import.meta.dirname, '../../docs');

try {
  buildPageTree(docsRoot);
} catch (error) {
  console.error(`check-navigation: ${(error as Error).message}`);
  process.exit(1);
}

console.log(`check-navigation: ${listPages(docsRoot).length} pages, all of them in the nav`);
