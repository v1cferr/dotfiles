// The markdown pipeline: it turns docs/ into pages without asking docs/ to change shape.
// The three plugins below are the whole of what is renderer-specific: docs/notes/repo/site.md
import fs from 'node:fs';
import path from 'node:path';
import { remarkMdxMermaid } from 'fumadocs-core/mdx-plugins';
import { defineConfig } from 'fumadocs-mdx/config';
import { remarkDocTitle } from './plugins/remark-doc-title.ts';
import { DOCS_ROOT } from './lib/docs-root.ts';
import { INDEX_FILE } from './lib/urls.ts';
import { remarkRepoLinks } from './plugins/remark-repo-links.ts';

/** Folders under docs/ that own a README, so a `history/` link lands on a page and not nowhere. */
function indexedFolders(root: string, prefix = ''): Set<string> {
  const found = new Set<string>();
  for (const entry of fs.readdirSync(path.join(root, prefix), { withFileTypes: true })) {
    if (entry.isDirectory()) {
      for (const folder of indexedFolders(root, path.posix.join(prefix, entry.name))) {
        found.add(folder);
      }
    } else if (INDEX_FILE.test(entry.name)) {
      found.add(prefix);
    }
  }
  return found;
}

// Read ONCE: `remarkPlugins` is called for every file compiled.
const repoLinks = { root: DOCS_ROOT, indexed: indexedFolders(DOCS_ROOT) };

export default defineConfig({
  mdxOptions: {
    // FIRST: the H1 leaves before anything renders it, and the link rewriting has to see the
    // targets exactly as the file wrote them.
    remarkPlugins: (plugins) => [
      remarkDocTitle,
      [remarkRepoLinks, repoLinks],
      // A ```mermaid fence becomes the component, so one source still has two renderers.
      remarkMdxMermaid,
      ...plugins,
    ],
  },
});
