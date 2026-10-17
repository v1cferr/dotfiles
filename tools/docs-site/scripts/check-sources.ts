// It checks the source snapshot AFTER `pages` joined it to the site, which is the first place both
// halves exist: the index and the HTML were built by two derivations, and this is where they must
// agree. What it proves: docs/notes/repo/site-sources.md
//
//   1. nothing sits under /_source/ that the index did not publish, and nothing it lists is missing;
//   2. every manifest is well formed and names only assets that exist;
//   3. every section a manifest cites is a heading id the page's HTML really has.
//
//   node check-sources.ts <site-dir>
import fs from 'node:fs';
import path from 'node:path';
import { assetUrl, isPageManifest, pageManifestUrl, SOURCE_BASE } from '../lib/source-manifest.ts';
import { docPathToUrl } from '../lib/urls.ts';

const SITE = path.resolve(process.argv[2] ?? 'out');
const BASE = path.join(SITE, SOURCE_BASE);
const TOP_LEVEL = new Set(['files', 'pages', 'index.json', 'revision.json']);

function walk(dir: string): string[] {
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .flatMap((entry) =>
      entry.isDirectory() ? walk(path.join(dir, entry.name)) : [path.join(dir, entry.name)],
    );
}

const problems: string[] = [];
const index = JSON.parse(fs.readFileSync(path.join(BASE, 'index.json'), 'utf8'));
const revision = JSON.parse(fs.readFileSync(path.join(BASE, 'revision.json'), 'utf8'));
if (revision.rev !== null && !/^[0-9a-f]{40}$/.test(revision.rev)) {
  problems.push(`revision.json holds ${JSON.stringify(revision.rev)}, which is not a commit`);
}

for (const name of fs.readdirSync(BASE)) {
  if (!TOP_LEVEL.has(name)) problems.push(`${SOURCE_BASE}/${name} is not part of the snapshot`);
}

const published = new Set<string>(Object.values(index.published));
for (const file of walk(path.join(BASE, 'files'))) {
  const name = path.relative(path.join(BASE, 'files'), file);
  if (!published.has(name)) problems.push(`files/${name} is published and the index never names it`);
}
for (const asset of published) {
  if (assetUrl(asset) === undefined) problems.push(`the index names ${asset}, which is not an asset name`);
  else if (!fs.existsSync(path.join(BASE, 'files', asset))) problems.push(`files/${asset} is missing`);
}

let manifests = 0;
let sections = 0;
for (const file of walk(path.join(BASE, 'pages'))) {
  manifests++;
  const manifest = JSON.parse(fs.readFileSync(file, 'utf8'));
  const where = path.relative(BASE, file);
  if (!isPageManifest(manifest)) {
    problems.push(`${where} is not a valid manifest`);
    continue;
  }
  if (path.join(SITE, pageManifestUrl(manifest.page) ?? '') !== file) {
    problems.push(`${where} claims to be the manifest of ${manifest.page}`);
  }
  const url = docPathToUrl(manifest.page);
  const htmlFile = path.join(SITE, url === '/' ? '' : url, 'index.html');
  if (!fs.existsSync(htmlFile)) {
    problems.push(`${where} describes ${url}, which the site did not publish`);
    continue;
  }
  const ids = new Set([...fs.readFileSync(htmlFile, 'utf8').matchAll(/\bid="([^"]+)"/g)].map(([, id]) => id));
  for (const related of manifest.files) {
    if (related.asset !== null && !published.has(related.asset)) {
      problems.push(`${where} points ${related.path} at ${related.asset}, which was not published`);
    }
    for (const section of related.sections) {
      sections++;
      // The index slugs the headings itself, so a drift from Fumadocs' slugger shows up HERE.
      if (!ids.has(section)) problems.push(`${where} cites #${section}, and ${url} has no such heading`);
    }
  }
}

if (problems.length > 0) {
  console.error(`\ncheck-sources: ${problems.length} problem(s)\n`);
  for (const problem of problems.toSorted()) console.error(`  ${problem}`);
  process.exit(1);
}

console.log(
  `check-sources: ${manifests} manifests, ${published.size} assets and ${sections} section ids agree with the site` +
    ` (revision ${revision.rev ?? 'unknown, a dirty tree'})`,
);
