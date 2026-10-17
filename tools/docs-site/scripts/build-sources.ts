// It writes the source snapshot the site's previews read: one manifest per page and the content of
// every file some page shows, by content hash. Run by sources.nix, and by `pnpm sources` for
// `pnpm dev`. What it publishes and why: docs/notes/repo/site-sources.md
//
//   node scripts/build-sources.ts <out-dir> [repo-root]
import fs from 'node:fs';
import path from 'node:path';
import { buildSourceIndex } from '../lib/source-index.ts';
import { pageManifestUrl, SOURCE_BASE } from '../lib/source-manifest.ts';

const [outArg, rootArg] = process.argv.slice(2);
if (!outArg) {
  console.error('usage: build-sources.ts <out-dir> [repo-root]');
  process.exit(2);
}
const OUT = path.resolve(outArg);
const ROOT = path.resolve(rootArg ?? path.join(process.cwd(), '../..'));

const started = performance.now();
const index = buildSourceIndex(ROOT);

if (index.problems.length > 0) {
  console.error(`\nbuild-sources: ${index.problems.length} file(s) the policy would publish look sensitive\n`);
  for (const problem of index.problems) console.error(`  ${problem}`);
  process.exit(1);
}

// A clean directory every run, so a file a page stopped citing does not linger as published.
fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(path.join(OUT, 'files'), { recursive: true });

let manifestBytes = 0;
for (const manifest of index.pages) {
  const url = pageManifestUrl(manifest.page)!;
  const target = path.join(OUT, url.slice(SOURCE_BASE.length + 1));
  fs.mkdirSync(path.dirname(target), { recursive: true });
  const json = JSON.stringify(manifest);
  manifestBytes += json.length;
  fs.writeFileSync(target, json);
}

const published = new Map<string, string>();
for (const manifest of index.pages) {
  for (const related of manifest.files) {
    const file = index.files.get(related.path)!;
    if (file.asset !== null) published.set(file.path, file.asset);
  }
}
let assetBytes = 0;
for (const [rel, asset] of [...published].toSorted(([a], [b]) => (a < b ? -1 : 1))) {
  const target = path.join(OUT, 'files', asset);
  if (fs.existsSync(target)) continue;
  const content = index.files.get(rel)!.content!;
  assetBytes += Buffer.byteLength(content);
  fs.writeFileSync(target, content);
}

// What check-sources.ts reconciles the output against, and what the CI log prints. NO timings
// in it: the file is part of the output, and the output is reproducible to the byte.
const { stats } = index;
const summary = {
  version: 1,
  pages: stats.pages,
  pagesWithFiles: stats.pagesWithFiles,
  eligibleFiles: stats.eligibleFiles,
  relations: stats.relations,
  publishedFiles: stats.publishedFiles,
  publishedBytes: stats.publishedBytes,
  assetBytes,
  manifestBytes,
  tooLarge: stats.tooLarge,
  unresolved: stats.unresolved,
  ineligible: stats.ineligible,
  ambiguous: stats.ambiguous,
  published: Object.fromEntries([...published].toSorted(([a], [b]) => (a < b ? -1 : 1))),
};
fs.writeFileSync(path.join(OUT, 'index.json'), JSON.stringify(summary));

const kib = (bytes: number) => `${(bytes / 1024).toFixed(1)} KiB`;
const total = stats.relations.direct + stats.relations.declared + stats.relations.module;
console.log(
  [
    `build-sources: ${stats.pagesWithFiles} of ${stats.pages} pages relate to ${published.size} files`,
    `  relations: ${total} (${stats.relations.direct} direct, ${stats.relations.declared} declared, ${stats.relations.module} module)`,
    `  eligible: ${stats.eligibleFiles} files under the policy, ${stats.tooLarge.length} over the size cap`,
    `  references: ${stats.unresolved.length} unresolved, ${stats.ineligible.length} kept out by the policy, ${stats.ambiguous.length} ambiguous`,
    `  output: ${kib(assetBytes)} of sources, ${kib(manifestBytes)} of manifests`,
    `  time: ${((performance.now() - started) / 1000).toFixed(2)}s`,
  ].join('\n'),
);
