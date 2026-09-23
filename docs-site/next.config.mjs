// The site is STATIC: `output: export` writes plain HTML, so Pages serves files and never Node.
// trailingSlash keeps the URLs MkDocs published: docs/notes/repo/site.md
import { createMDX } from 'fumadocs-mdx/next';

/** @type {import('next').NextConfig} */
const config = {
  output: 'export',
  trailingSlash: true,
  // `export` cannot run the optimizer, and there is no image in docs/ anyway.
  images: { unoptimized: true },
  // docs/ lives OUTSIDE this directory on purpose (rule 20): the tree never moves for a renderer.
  outputFileTracingRoot: new URL('..', import.meta.url).pathname,
};

export default createMDX()(config);
