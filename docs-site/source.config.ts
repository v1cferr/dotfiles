// The markdown pipeline: it turns docs/ into pages without asking docs/ to change shape.
// The three plugins below are the whole of what is renderer-specific: docs/notes/repo/site.md
import fs from 'node:fs';
import path from 'node:path';
import { rehypeCodeDefaultOptions, remarkMdxMermaid } from 'fumadocs-core/mdx-plugins';
import { defineConfig } from 'fumadocs-mdx/config';
import { type BundledLanguage, bundledLanguages } from 'shiki';
import { DOCS_ROOT } from './lib/docs-root.ts';
import { listPages } from './lib/page-tree.ts';
import { INDEX_FILE } from './lib/urls.ts';
import { remarkDocTitle } from './plugins/remark-doc-title.ts';
import { remarkRepoLinks } from './plugins/remark-repo-links.ts';

/** Every language a fence in docs/ asks for, so shiki can load them all up front. */
function fenceLanguages(root: string): BundledLanguage[] {
  const found = new Set<string>();
  for (const page of listPages(root)) {
    const source = fs.readFileSync(path.join(root, page), 'utf8');
    for (const [, lang] of source.matchAll(/^\s*(?:```|~~~)+([a-zA-Z0-9_+-]+)/gm)) found.add(lang);
  }
  // A name shiki does not ship is not a language it can preload: `text` and `mermaid` are here.
  return [...found].filter((lang) => lang in bundledLanguages).toSorted() as BundledLanguage[];
}

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
    // PRELOADED, and this is reproducibility and not speed: shiki loads a grammar on first use,
    // and a language used by exactly one fence came out unhighlighted on some builds and not
    // others. `nix build --rebuild` is what caught it.
    rehypeCodeOptions: { ...rehypeCodeDefaultOptions, langs: fenceLanguages(DOCS_ROOT) },
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
