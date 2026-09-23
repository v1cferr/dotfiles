// The site is STATIC: `output: export` writes plain HTML, so Pages serves files and never Node.
// trailingSlash keeps the URLs MkDocs published: docs/notes/repo/site.md
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { createMDX } from 'fumadocs-mdx/next';

const ROOT = process.cwd();
const DOCS = path.resolve(ROOT, '../docs');

// What is GENERATED, so hashing the sources below does not hash the previous build.
const GENERATED = new Set(['node_modules', '.next', '.source', 'out', 'next-env.d.ts', '.git']);

function sources(dir, found = []) {
  const entries = fs
    .readdirSync(dir, { withFileTypes: true })
    .toSorted((a, b) => (a.name < b.name ? -1 : 1));
  for (const entry of entries) {
    if (GENERATED.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) sources(full, found);
    else found.push(full);
  }
  return found;
}

// THE BUILD ID IS A CONTENT HASH, because Next.js otherwise mints a random one and two builds of
// the same commit stop being the same site. Measured: `nix build --rebuild` said so.
function buildId() {
  const hash = crypto.createHash('sha256');
  for (const file of [...sources(DOCS), ...sources(ROOT)]) {
    hash.update(path.relative(ROOT, file));
    hash.update(fs.readFileSync(file));
  }
  return hash.digest('base64url').slice(0, 21);
}

/** @type {import('next').NextConfig} */
const config = {
  output: 'export',
  trailingSlash: true,
  generateBuildId: buildId,
  // `export` cannot run the optimizer, and there is no image in docs/ anyway.
  images: { unoptimized: true },
  // docs/ lives OUTSIDE this directory on purpose (rule 20): the tree never moves for a renderer.
  outputFileTracingRoot: path.resolve(ROOT, '..'),
  // `next dev` WRITES an AGENTS.md and a CLAUDE.md into this directory otherwise. The agent
  // contract of this machine is declared once, in /etc (rule 18), and is not a build artifact.
  agentRules: false,
};

export default createMDX()(config);
